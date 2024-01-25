struct DoubleBoundedConstraint
    arc_to_coefficient::Dict{Arc,Float64}
    lower_bound::Float64
    upper_bound::Float64
    violation_penalty_cost::Float64
end

"""
    NetworkFlowProblemBuilder

This structure is used to build network flow problems. The builder allows the user to
define a network with vertices, arcs, and commodities, and side constraints.  

# Usage
Creating a new instance of the builder:
```julia
builder = new_problem_builder()
```

Adding elements to the problem:
```julia
vertex = new_vertex!(builder)
arc = new_arc!(builder, vertex1, vertex2)
commodity = new_commodity!(builder, source_vertex, sink_vertex, demand, capacity)
```

Setting arc properties:
```julia
set_cost!(builder, arc, cost)
set_capacity!(builder, arc, capacity)
set_var_type!(builder, arc, var_type)
```

Defining a side-constraint:
```julia
constraint = new_constraint!(builder, lb, ub)
set_constraint_coefficient!(builder, constraint, arc, coefficient)
```

Once the problem is fully constructed, it can be converted into a NetworkFlowModel.Problem and optimized using an appropriate MIP solver:
```julia
problem = get_problem(builder)
solution = optimize!(problem, mip_solver)
```

# Examples
```julia
builder = new_problem_builder()
v1 = new_vertex!(builder)
v2 = new_vertex!(builder)
v3 = new_vertex!(builder)
arc1 = new_arc!(builder, v1, v2; cost=5.0, capacity=10.0, var_type=CONTINUOUS)
arc2 = new_arc!(builder, v1, v2; var_type=INTEGER)
set_cost!(builder, arc2, 7.0)
commodity = new_commodity!(builder, v1, v3, 2.0, 10.0)
constraint = new_constraint!(builder, lb=9.0, ub=10.0
set_constraint_coefficient!(builder, constraint, arc1, 1.0)
set_constraint_coefficient!(builder, constraint, arc2, 2.0)
problem = get_problem(builder)
mip_solver = HiGHS.Optimizer
solution = optimize!(problem, mip_solver)
```
"""
struct NetworkFlowProblemBuilder
    vertices::Vector{Vertex}
    arcs::Vector{Arc}
    double_bounded_constraints::Vector{DoubleBoundedConstraint}
    commodities::Vector{Commodity}
    arc_costs::Vector{Float64}
    arc_capacities::Vector{Float64}
    arc_var_types::Vector{VarType}

    function NetworkFlowProblemBuilder()
        return new(
            Vector{Vertex}(),
            Vector{Arc}(),
            Vector{Constraint}(),
            Vector{Commodity}(),
            Vector{Float64}(),
            Vector{Float64}(),
            Vector{VarType}(),
        )
    end
end

"""
    new_problem_builder()

Create a new empty instance of NetworkFlowProblemBuilder.
"""
new_problem_builder() = NetworkFlowProblemBuilder()

"""
    new_vertex!(builder::NetworkFlowProblemBuilder)

Create a new vertex in the network flow problem builder.
"""
function new_vertex!(builder::NetworkFlowProblemBuilder)
    vertex = Vertex(length(builder.vertices) + 1)
    push!(builder.vertices, vertex)
    return vertex
end

"""
    new_arc!(
        builder::NetworkFlowProblemBuilder,
        tail::Vertex,
        head::Vertex;
        cost::Float64 = 0.0,
        capacity::Float64 = Inf,
        var_type::VarType = CONTINUOUS,
    )

Create a new arc in the network flow problem builder.

Note: VarType can be either `CONTINUOUS` or `INTEGER`
"""
function new_arc!(
    builder::NetworkFlowProblemBuilder,
    tail::Vertex,
    head::Vertex;
    cost::Float64 = 0.0,
    capacity::Float64 = Inf,
    var_type::VarType = CONTINUOUS,
)
    return new_arc!(builder, (tail, 1.0), head; cost, capacity, var_type)
end

"""
    new_arc!(
        builder::NetworkFlowProblemBuilder,
        (tail, multiplier)::Tuple{Vertex,Float64},
        head::Vertex;
        cost::Float64 = 0.0,
        capacity::Float64 = Inf,
        var_type::VarType = CONTINUOUS,
    )

Create a new arc in the network flow problem builder.

Note: VarType can be either `CONTINUOUS` or `INTEGER
"""
function new_arc!(
    builder::NetworkFlowProblemBuilder,
    (tail, multiplier)::Tuple{Vertex,Float64},
    head::Vertex;
    cost::Float64 = 0.0,
    capacity::Float64 = Inf,
    var_type::VarType = CONTINUOUS,
)
    arc = NetworkFlowModel.new_arc(length(builder.arcs) + 1, (tail, multiplier), head)
    push!(builder.arcs, arc)
    push!(builder.arc_costs, cost)
    push!(builder.arc_capacities, capacity)
    push!(builder.arc_var_types, var_type)

    return arc
end

"""
    new_arc!(
        builder::NetworkFlowProblemBuilder,
        tail_to_multiplier_map::Dict{Vertex,Float64},
        head::Vertex;
        cost::Float64 = 0.0,
        capacity::Float64 = Inf,
        var_type::VarType = CONTINUOUS,
    )

Create a new (hyper-)arc in the network flow problem builder.

Note: VarType can be either `CONTINUOUS` or `INTEGER`
"""
function new_arc!(
    builder::NetworkFlowProblemBuilder,
    tail_to_multiplier_map::Dict{Vertex,Float64},
    head::Vertex;
    cost::Float64 = 0.0,
    capacity::Float64 = Inf,
    var_type::VarType = CONTINUOUS,
)
    arc = NetworkFlowModel.new_arc(length(builder.arcs) + 1, tail_to_multiplier_map, head)
    push!(builder.arcs, arc)
    push!(builder.arc_costs, cost)
    push!(builder.arc_capacities, capacity)
    push!(builder.arc_var_types, var_type)

    return arc
end

"""
    new_commodity!(
        builder::NetworkFlowProblemBuilder,
        source::Vertex,
        sink::Vertex,
        demand::Number,
        capacity::Number;
        violation_penalty_cost::Number = 1e3,
    )

Add a new commodity to the network flow problem builder.
"""
function new_commodity!(
    builder::NetworkFlowProblemBuilder,
    source::Vertex,
    sink::Vertex,
    demand::Number,
    capacity::Number;
    violation_penalty_cost::Number = 1e3,
)
    commodity = Commodity(
        length(builder.commodities) + 1,
        source,
        sink,
        Float64(demand),
        Float64(capacity),
        Float64(violation_penalty_cost),
    )
    push!(builder.commodities, commodity)
    return commodity
end

"""
    new_constraint!(
        builder::NetworkFlowProblemBuilder;
        lb::Float64 = -Inf,
        ub::Float64 = Inf,
        violation_penalty_cost::Float64 = 1e3,
    )

Create a new linear constraint and add it to the network flow problem builder.

# Exceptions
- `ArgumentError`: If the lower bound is greater than the upper bound, or if the bounds are infeasible or unbounded.
"""
function new_constraint!(
    builder::NetworkFlowProblemBuilder;
    lb::Float64 = -Inf,
    ub::Float64 = Inf,
    violation_penalty_cost::Float64 = 1e3,
)
    if lb > ub
        throw(
            ArgumentError("Lower bound $lb must be less than or equal to upper bound $ub")
        )
    elseif lb == -Inf && ub == Inf
        throw(ArgumentError("Unbounded constraint"))
    elseif lb == Inf || ub == -Inf
        throw(ArgumentError("Infeasible bounds"))
    end

    constraint = DoubleBoundedConstraint(Dict(), lb, ub, violation_penalty_cost)
    push!(builder.double_bounded_constraints, constraint)
    return constraint
end

"""
    set_cost!(builder::NetworkFlowProblemBuilder, arc::Arc, cost::Float64)

Set the cost of an arc in the network flow problem builder.
"""
function set_cost!(builder::NetworkFlowProblemBuilder, arc::Arc, cost::Float64)
    return builder.arc_costs[arc.index] = cost
end

"""
    set_capacity!(builder::NetworkFlowProblemBuilder, arc::Arc, capacity::Float64)

Set the capacity of an arc in the network flow problem builder.
"""
function set_capacity!(builder::NetworkFlowProblemBuilder, arc::Arc, capacity::Float64)
    return builder.arc_capacities[arc.index] = capacity
end

"""
    set_var_type!(builder::NetworkFlowProblemBuilder, arc::Arc, var_type::VarType)

Set the variable type of an arc in the network flow problem builder.
"""
function set_var_type!(builder::NetworkFlowProblemBuilder, arc::Arc, var_type::VarType)
    return builder.arc_var_types[arc.index] = var_type
end

"""
    set_constraint_coefficient!(
        builder::NetworkFlowProblemBuilder,
        constraint::DoubleBoundedConstraint,
        arc::Arc,
        coeff::Float64,
    )

Set the coefficient of an arc in a linear constraint in the network flow problem builder.
"""
function set_constraint_coefficient!(
    builder::NetworkFlowProblemBuilder,
    constraint::DoubleBoundedConstraint,
    arc::Arc,
    coeff::Float64,
)
    constraint.arc_to_coefficient[arc] = coeff
    return nothing
end

function _get_linear_constraints(builder::NetworkFlowProblemBuilder)
    constraints = Vector{Constraint}()
    for dbc in builder.double_bounded_constraints
        ctrs_to_add = Tuple{ConstraintType,Float64}[]
        if dbc.lower_bound == dbc.upper_bound
            push!(ctrs_to_add, (EQ, dbc.lower_bound))
        else
            if dbc.lower_bound > -Inf
                push!(ctrs_to_add, (GEQ, dbc.lower_bound))
            end
            if dbc.upper_bound < Inf
                push!(ctrs_to_add, (LEQ, dbc.upper_bound))
            end
        end
        for (constraint_type, RHS) in ctrs_to_add
            constraint = Constraint(
                length(constraints) + 1,
                dbc.arc_to_coefficient,
                constraint_type,
                RHS,
                dbc.violation_penalty_cost,
            )
            push!(constraints, constraint)
        end
    end
    return constraints
end

"""
    get_problem(builder::NetworkFlowProblemBuilder)

Create a NetworkFlowModel.Problem based on the data given in NetworkFlowProblemBuilder.
"""
function get_problem(builder::NetworkFlowProblemBuilder)
    network = Network(builder.vertices, builder.arcs)
    problem = NetworkFlowModel.Problem(
        network,
        arc -> builder.arc_costs[arc.index],
        arc -> builder.arc_capacities[arc.index],
        arc -> builder.arc_var_types[arc.index],
        _get_linear_constraints(builder),
        builder.commodities,
    )

    return problem
end

"""
    optimize!(
        problem::NetworkFlowModel.Problem,
        mip_solver;
        initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
        obj_cutoff = Inf,
    )

Optimize the network flow problem using FlowGenerator internal solver based on the specified MIP optimizer.

Returns a `PrimalSolution` object.
"""
function optimize!(
    problem::NetworkFlowModel.Problem,
    mip_solver;
    initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
    obj_cutoff = Inf,
)
    params = Parameters.new_network_flow_solver_params(mip_solver; obj_cutoff)
    return optimize!(problem, params; initial_paths)
end

"""
    optimize!(
        problem::NetworkFlowModel.Problem,
        params::Parameters.AbstractSolverParams;
        initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
    )

Optimize the network flow problem using the specified solver parameters.

Returns a `PrimalSolution` object.
"""
function optimize!(
    problem::NetworkFlowModel.Problem,
    params::Parameters.AbstractSolverParams;
    initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
)
    solution = NetworkFlowSolver.solve(
        problem, params; initial_paths, params.max_num_branching_levels
    )

    println(
        "\nFlowGenerator: Optimization finished with a primal bound $(get_obj_val(problem, solution))",
    )

    return solution
end

"""
    optimize_by_mip_solver!(problem::NetworkFlowModel.Problem, mip_solver; time_limit::Float64 = 3600)

Optimize the network flow problem directly by an external MIP solver. Keyword parameter time_limit is given in seconds.

Returns a `PrimalSolution` object.
"""
function optimize_by_mip_solver!(
    problem::NetworkFlowModel.Problem, mip_solver; time_limit::Float64 = Inf
)
    params = Parameters.MipSolverParams(; mip_optimizer = mip_solver)
    solution = MipModel.solve(problem, params; time_limit)

    println(
        "\nFlowGenerator: Optimization finished with a primal bound $(get_obj_val(problem, solution))",
    )

    return solution
end

"""
    optimize_linear_relaxation!(problem::NetworkFlowModel.Problem, mip_solver; use_column_generation::Bool = false)

Optimize the network flow problem while ignoring all variable integrality constraints.
"""
function optimize_linear_relaxation!(
    problem::NetworkFlowModel.Problem, mip_solver; use_column_generation::Bool = false
)
    lp_solver_params = Parameters.MipSolverParams(;
        mip_optimizer = mip_solver,
        linear_relaxation = true,
        is_silent = use_column_generation,
    )
    solution = if use_column_generation
        params = Parameters.ColumnGenerationParams(; lp_solver_params)
        ColumnGeneration.get_primal_solution(ColumnGeneration.solve(problem, params))
    else
        solution = MipModel.solve(problem, lp_solver_params)
    end
    return solution
end

"""
    filter_arcs_by_reduced_cost(problem::Problem, mip_solver, cutoff::Number)

Remove arcs that are not good candidates to find a solution better than cutoff.

Returns the filtered problem.
"""
function filter_arcs_by_reduced_cost(
    problem::NetworkFlowModel.Problem, mip_solver, cutoff::Number
)
    lp_solver_params = Parameters.MipSolverParams(;
        mip_optimizer = mip_solver, is_silent = true
    )
    params = Parameters.ColumnGenerationParams(; lp_solver_params)
    cg_solution = ColumnGeneration.solve(problem, params)
    initial_number_of_arcs = length(get_arcs(get_network(problem)))
    problem = NetworkFlowSolver.reduced_cost_fixing(problem, cg_solution, cutoff)
    new_number_of_arcs = length(get_arcs(get_network(problem)))
    println(
        "\nFlowGenerator: Reduced cost filtering removed $(initial_number_of_arcs - new_number_of_arcs) out of $initial_number_of_arcs arcs",
    )
    return problem
end

"""
    get_flow(solution::NetworkFlowModel.PrimalSolution, commodity::Commodity, arc::Arc)

Return the flow for a specific commodity and arc in the given solution.
"""
function get_flow(solution::NetworkFlowModel.PrimalSolution, commodity::Commodity, arc::Arc)
    return get(get_arc_to_flow_map(solution, commodity), arc, 0.0)
end

"""
    get_flow(solution::NetworkFlowModel.PrimalSolution, arc::Arc)

Return the total flow for a specific arc in the given solution.
"""
function get_flow(solution::NetworkFlowModel.PrimalSolution, arc::Arc)
    return sum(
        get(arc_flow_solution.arc_to_flow_map, arc, 0.0) for
        (_, arc_flow_solution) in solution.commodity_to_arc_flow_solution;
        init = 0.0,
    )
end

"""
    get_obj_val(problem::NetworkFlowModel.Problem, solution::NetworkFlowModel.PrimalSolution)

Return the objective value for the given problem and solution.
"""
function get_obj_val(
    problem::NetworkFlowModel.Problem, solution::NetworkFlowModel.PrimalSolution
)
    return NetworkFlowModel.get_obj_val(problem, solution)
end

"""
    get_path_to_flow_map(
        problem::NetworkFlowModel.Problem,
        solution::NetworkFlowModel.PrimalSolution,
        commodity::Commodity,
    )

Return the path to flow map for a specific commodity in the given solution.
"""
function get_path_to_flow_map(
    problem::Problem, primal_solution::NetworkFlowModel.PrimalSolution, commodity::Commodity
)
    arc_flow_solution = NetworkFlowModel.get_arc_flow_solution(primal_solution, commodity)
    path_flow_solution = NetworkFlowModel.convert_to_path_flow_solution(
        get_network(problem), arc_flow_solution
    )
    return NetworkFlowModel.get_path_to_flow_map(path_flow_solution)
end

"""
    get_arcs(path::Path)

Return the arcs in a path. The arcs do not follow any particular order.
"""
function get_arcs(path::Path)
    return collect(keys(get_arc_to_multiplicity(path)))
end

"""
    get_arcs(network::Network)

Return the arcs in a network.
"""
function get_arcs(network::Network)
    return collect(NetworkFlowModel.get_arcs(network))
end
