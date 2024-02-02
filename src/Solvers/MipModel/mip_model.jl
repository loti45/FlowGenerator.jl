"""
    struct NetworkFlowMipModel

A struct for representing a mixed-integer programming (MIP) model for network flow problems.

# Fields
- `mip_model::JuMP.Model`: The JuMP model object for the MIP.
- `problem::NetworkFlowModel.Problem`: The network flow problem instance.
- `commodity_to_flow_data::Dict{Commodity,CommodityFlowComponent}`: A dictionary mapping commodities to their respective flow components.
- `arc_to_capacity_constraint::Dict{NetworkFlowModel.Arc,JuMP.ConstraintRef}`: A dictionary mapping arcs to their capacity constraints in the MIP model.
- `side_constrs::Vector{JuMP.ConstraintRef}`: A vector of additional side constraints added to the MIP model.
- `dual_decimal_precision::Int`: The precision used for the dual values retrieved from the JuMP model.

This struct is used to encapsulate all the components necessary to define and solve a MIP for a network flow problem, including the model itself, the problem data, constraints, and settings for numerical precision.
"""
struct NetworkFlowMipModel
    mip_model::JuMP.Model
    problem::NetworkFlowModel.Problem
    commodity_to_flow_data::Dict{Commodity,CommodityFlowComponent}
    arc_to_capacity_constraint::Dict{NetworkFlowModel.Arc,JuMP.ConstraintRef}
    side_constrs::Vector{JuMP.ConstraintRef}
    dual_decimal_precision::Int
end

"""
    NetworkFlowMipModel(
        problem::NetworkFlowModel.Problem, 
        params::MipSolverParams
    ) -> NetworkFlowMipModel

Create a new mixed-integer programming (MIP) model for a network flow problem.

# Returns
- `NetworkFlowMipModel`: A `NetworkFlowMipModel` instance with initialized MIP model, constraints, and variables.
"""
function NetworkFlowMipModel(problem::NetworkFlowModel.Problem, params::MipSolverParams)
    output = NetworkFlowMipModel(
        JuMP.Model(params.mip_optimizer),
        problem,
        Dict(),
        Dict(),
        [],
        params.dual_decimal_precision,
    )
    @objective(output.mip_model, Min, 0.0)
    if params.is_silent
        set_silent(output.mip_model)
    end
    for commodity in get_commodities(problem)
        output.commodity_to_flow_data[commodity] = CommodityFlowComponent(
            output.mip_model, commodity; params.primal_decimal_precision
        )
    end
    for arc in get_arcs(get_network(problem))
        if get_capacity(problem, arc) < Inf
            output.arc_to_capacity_constraint[arc] = @constraint(
                output.mip_model, 0.0 <= get_capacity(problem, arc)
            )
        end
    end
    for constr in problem.constraints
        _add_constraint!(output, constr)
    end

    return output
end

"""
    optimize!(model::NetworkFlowMipModel; time_limit::Float64 = Inf)

Optimize the MIP model associated with a network flow problem by calling `JuMP.optimize!()`.
time_limit is given in seconds.

# Returns
- `nothing`.
"""
function optimize!(model::NetworkFlowMipModel; time_limit::Float64 = Inf)
    if time_limit < Inf
        set_time_limit_sec(model.mip_model, time_limit)
    end
    JuMP.optimize!(model.mip_model)
    return nothing
end

"""
    add_column!(
        model::NetworkFlowMipModel,
        column::Column,
    ) -> Bool

Add a column/variable to the MIP model representing the flow of a commodity along a specific hyper-tree.
The hyper-tree can represent a single hyper-arc, a partial hyper-tree, or a complete hyper-tree from the source to the sink of the commodity.
The variable is added only if the hyper-tree is in the network of the problem and an equivalent variable does not already exist.

# Returns
- `true` if the variable was successfully added, otherwise `false`.
"""
function add_column!(model::NetworkFlowMipModel, column::Column)
    if !(column.hyper_tree in get_network(model.problem))
        return false
    end
    var = add_column!(model.commodity_to_flow_data[column.commodity], column)
    if isnothing(var)
        return false
    end

    # setting side constraints
    constr_index_to_coeff = Dict{Int,Float64}()
    for (arc, mult) in get_arc_to_multiplicity(column.hyper_tree)
        for (index, coeff) in NetworkFlowModel.get_constr_coeff_list(model.problem, arc)
            constr_index_to_coeff[index] =
                get(constr_index_to_coeff, index, 0.0) + coeff * mult
        end
    end
    for (index, coeff) in constr_index_to_coeff
        set_normalized_coefficient(model.side_constrs[index], var, coeff)
    end

    for (arc, multiplicity) in get_arc_to_multiplicity(column.hyper_tree)
        _set_capacity_coeff!(model, arc, var; multiplicity)
    end
    return true
end

"""
    get_primal_solution(model::NetworkFlowMipModel) -> PrimalSolution

Retrieve the primal solution from a solved MIP model
"""
function get_primal_solution(model::NetworkFlowMipModel)
    commodity_to_arc_flow_solution = Dict{Commodity,NetworkFlowModel.ArcFlowSolution}()
    for commodity in get_commodities(model.problem)
        commodity_to_arc_flow_solution[commodity] = get_arc_flow_solution(
            model.commodity_to_flow_data[commodity]
        )
    end
    return PrimalSolution(commodity_to_arc_flow_solution)
end

"""
    get_dual_solution(model::NetworkFlowMipModel) -> DualSolution

Retrieve the dual solution from a solved NetworkFlowMipModel. Only works if the model is an LP model (all variables are linear).
"""
function get_dual_solution(model::NetworkFlowMipModel)
    digits = model.dual_decimal_precision
    return NetworkFlowModel.DualSolution(
        Dict(
            commodity => round(dual(flow_data.demand_constraint); digits) for
            (commodity, flow_data) in model.commodity_to_flow_data
        ),
        Dict(
            commodity => round(dual(flow_data.capacity_constraint); digits) for
            (commodity, flow_data) in model.commodity_to_flow_data
        ),
        Dict(
            constr => round(dual(model.side_constrs[constr.index]); digits) for
            constr in NetworkFlowModel.get_constraints(model.problem)
        ),
        Dict(
            arc => round(dual(constr); digits) for
            (arc, constr) in model.arc_to_capacity_constraint
        ),
    )
end

function _add_constraint!(model, constr)
    artificial_var = JuMP.@variable(model.mip_model; lower_bound = 0)
    set_objective_coefficient(
        model.mip_model, artificial_var, constr.violation_penalty_cost
    )

    side_constraint = if constr.constraint_type == NetworkFlowModel.GEQ
        @constraint(model.mip_model, artificial_var >= constr.RHS)
    elseif constr.constraint_type == NetworkFlowModel.LEQ
        @constraint(model.mip_model, -artificial_var <= constr.RHS)
    elseif constr.constraint_type == NetworkFlowModel.EQ
        @constraint(model.mip_model, artificial_var == constr.RHS)
    end
    push!(model.side_constrs, side_constraint)
    return nothing
end

function _set_capacity_coeff!(model, arc, var; multiplicity = 1.0)
    if get_capacity(model.problem, arc) < Inf
        set_normalized_coefficient(model.arc_to_capacity_constraint[arc], var, multiplicity)
    end
end

"""
    get_columns(mip_model::NetworkFlowMipModel, commodity::Commodity) -> Vector{Column}

Get all columns associated with the given commodity.
"""
function get_columns(mip_model::NetworkFlowMipModel, commodity::Commodity)
    return get_columns(mip_model.commodity_to_flow_data[commodity])
end
