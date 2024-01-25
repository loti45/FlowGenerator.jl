"""
    struct CommodityFlowComponent

A struct for representing the flow component of a specific commodity within a network flow model.

Contains a JuMP implementation of:
- the arc and path flow variables and flow conservation constraints associated with the commodity;
- the flow demand and capacity constraints of the commodity.
"""
struct CommodityFlowComponent
    commodity::Commodity
    mip_model::JuMP.Model
    arc_to_var::OrderedDict{NetworkFlowModel.Arc,JuMP.VariableRef} # ordered to make get_arcs deterministic
    path_to_var::OrderedDict{NetworkFlowModel.Path,JuMP.VariableRef} # ordered to make get_paths deterministic
    vertex_to_flow_conservation_constr::OrderedDict{
        NetworkFlowModel.Vertex,JuMP.ConstraintRef
    }
    demand_constraint::JuMP.ConstraintRef
    capacity_constraint::JuMP.ConstraintRef
    primal_decimal_precision::Int

    function CommodityFlowComponent(mip_model, commodity; primal_decimal_precision)
        artificial_var = JuMP.@variable(mip_model; lower_bound = 0)
        set_objective_coefficient(
            mip_model, artificial_var, commodity.violation_penalty_cost
        )
        demand_constraint = @constraint(mip_model, artificial_var >= commodity.demand)
        capacity_constraint = @constraint(mip_model, artificial_var <= commodity.capacity)
        return new(
            commodity,
            mip_model,
            OrderedDict{NetworkFlowModel.Arc,JuMP.VariableRef}(),
            OrderedDict{NetworkFlowModel.Path,JuMP.VariableRef}(),
            OrderedDict{NetworkFlowModel.Vertex,JuMP.ConstraintRef}(),
            demand_constraint,
            capacity_constraint,
            primal_decimal_precision,
        )
    end
end

"""
    add_path_var!(flow_component::CommodityFlowComponent, path::Path, cost::Float64)

Add a flow variable for a specified path to the `CommodityFlowComponent` if it does not already exist.

# Returns
- `var`: The JuMP variable reference for the newly added path variable. Returns `nothing` if the variable already exists.

This function creates a variable associated with a specific path in the network, assigns it a cost coefficient in the objective function, and updates the demand and capacity constraints to include this variable.
"""
function add_path_var!(flow_component::CommodityFlowComponent, path::Path, cost::Float64)
    if haskey(flow_component.path_to_var, path)
        return nothing
    end

    var = JuMP.@variable(flow_component.mip_model; lower_bound = 0)
    set_objective_coefficient(flow_component.mip_model, var, cost)
    flow_component.path_to_var[path] = var

    set_normalized_coefficient(flow_component.demand_constraint, var, 1.0)
    set_normalized_coefficient(flow_component.capacity_constraint, var, 1.0)

    return var
end

"""
    add_arc_var!(
        flow_component::CommodityFlowComponent, arc::Arc, cost::Float64; var_type::VarType
    )

Add a flow variable for a specified arc to the `CommodityFlowComponent` if it does not already exist.

# Returns
- `var`: The JuMP variable reference for the newly added arc variable. Returns `nothing` if the variable already exists.

This function creates a variable associated with a specific arc in the network, assigns it a cost coefficient in the objective function, and updates flow conservation and commodity flow constraints to include this variable.
"""
function add_arc_var!(
    flow_component::CommodityFlowComponent, arc::Arc, cost::Float64; var_type::VarType
)
    if haskey(flow_component.arc_to_var, arc)
        return nothing
    end

    is_integer = var_type == INTEGER
    var = JuMP.@variable(flow_component.mip_model; lower_bound = 0, integer = is_integer)
    set_objective_coefficient(flow_component.mip_model, var, cost)
    flow_component.arc_to_var[arc] = var

    # setting flow conservation constraints
    if arc.head != flow_component.commodity.sink
        set_normalized_coefficient(
            get_flow_conservation_constraint!(flow_component, arc.head), var, 1.0
        )
    end

    for (tail, multiplier) in get_tail_multiplier_list(arc)
        if tail != flow_component.commodity.source
            set_normalized_coefficient(
                get_flow_conservation_constraint!(flow_component, tail), var, -multiplier
            )
        end
    end

    # setting commodity flow constraints
    if arc.head == flow_component.commodity.sink
        set_normalized_coefficient(flow_component.demand_constraint, var, 1.0)
        set_normalized_coefficient(flow_component.capacity_constraint, var, 1.0)
    end

    return var
end

"""
    get_flow_conservation_constraint!(
        flow_component::CommodityFlowComponent, vertex::Vertex
    )

Retrieve or create a flow conservation constraint for a specified vertex within the `CommodityFlowComponent`.

# Returns
- `constraint::JuMP.ConstraintRef`: The JuMP constraint reference for the flow conservation at the specified vertex.

This function ensures that there is a flow conservation constraint for each vertex. If the constraint does not exist, it is created with a default expression of `0.0 == 0.0`.
"""
function get_flow_conservation_constraint!(
    flow_component::CommodityFlowComponent, vertex::Vertex
)
    return get!(
        flow_component.vertex_to_flow_conservation_constr,
        vertex,
        JuMP.@constraint(flow_component.mip_model, 0.0 == 0.0)
    )
end

"""
    delete_arc_var!(flow_component::CommodityFlowComponent, arc::Arc)

Delete an arc variable from the `CommodityFlowComponent` by setting the upper bound to 0 and removing it from assocaited data structures.

Note: setting the variable upper bound to 0 is more efficient than effectively deleting the variable.
"""
function delete_arc_var!(flow_component::CommodityFlowComponent, arc::Arc)
    #delete(cg.rmp, cg.arc_to_var[arc]) # setting upper bound to 0 is more efficient than deleting
    set_upper_bound(flow_component.arc_to_var[arc], 0.0)
    delete!(flow_component.arc_to_var, arc)
    return nothing
end

"""
    delete_path_var!(flow_component::CommodityFlowComponent, path::Path)

Delete a path variable from the `CommodityFlowComponent` by setting the upper bound to 0 and removing it from assocaited data structures.

Note: setting the variable upper bound to 0 is more efficient than deleting the variable.
"""
function delete_path_var!(flow_component::CommodityFlowComponent, path::Path)
    #delete(cg.rmp, cg.path_to_var[path]) # setting upper bound to 0 is more efficient than deleting
    set_upper_bound(flow_component.path_to_var[path], 0.0)
    delete!(flow_component.path_to_var, path)
    return nothing
end

"""
    get_arc_flow_solution(flow_component::CommodityFlowComponent) -> ArcFlowSolution

Retrieve the flow solution for all arcs within the `CommodityFlowComponent`.

This function calculates the flow solution for each arc by rounding the value of the associated variable and aggregating the flow values from the path variables as well.
"""
function get_arc_flow_solution(flow_component::CommodityFlowComponent)
    arc_to_flow_map = Dict{Arc,Float64}()
    for (arc, var) in flow_component.arc_to_var
        val = round(value(var); digits = flow_component.primal_decimal_precision)
        if val > 0.0
            arc_to_flow_map[arc] = val
        end
    end
    for (path, var) in flow_component.path_to_var
        val = round(value(var); digits = flow_component.primal_decimal_precision)
        if val > 0.0
            for (arc, mult) in get_arc_to_multiplicity(path)
                arc_to_flow_map[arc] = get(arc_to_flow_map, arc, 0.0) + val * mult
            end
        end
    end

    commodity = flow_component.commodity
    return NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, commodity.source, commodity.sink
    )
end

"""
    get_paths(flow_component::CommodityFlowComponent)

Return all paths for which variables have been created in the `CommodityFlowComponent`.
"""
function get_paths(flow_component::CommodityFlowComponent)
    return keys(flow_component.path_to_var)
end

"""
    get_arcs(flow_component::CommodityFlowComponent)

Return all arcs for which variables have been created in the `CommodityFlowComponent`.
"""
function NetworkFlowModel.get_arcs(flow_component::CommodityFlowComponent)
    return keys(flow_component.arc_to_var)
end
