"""
    @enum VarType

An Enum type representing different variable types for arcs in a flow network problem.

# Values
- `INTEGER`: Indicates that the variable is restricted to integer values.
- `CONTINUOUS`: Indicates that the variable can take any continuous real value.
"""
@enum VarType INTEGER CONTINUOUS

"""
    struct Problem

Encapsulates the data needed to define and solve a network flow optimization problem.

# Fields
- `network::Network`: Represents the flow network with nodes and arcs.
- `objective_function::ObjectiveFunction`: A linear function defining the objective of the optimization.
- `arc_to_capacity_map::IndexedMap{Arc,Float64}`: A mapping from arcs to their capacities.
- `arc_to_var_type_map::IndexedMap{Arc,VarType}`: A mapping from arcs to their variable types, either `INTEGER` or `CONTINUOUS`.
- `constraints::Vector{Constraint}`: A vector of generic linear side-constraints.
- `commodities::Vector{Commodity}`: A vector of commodities to be sent through the network.
- `arc_to_side_constr_coeffs::LinkedListMap{Tuple{Int,Float64}}`: An auxiliary mapping for side constraints coefficients for enhanced solution computation. To be computed by constructors.

# Constructors
- `Problem(network, arc_to_cost, arc_to_capacity, arc_to_var_type, constraints, commodities)`: Constructs a `Problem` instance given network parameters and functions to define arc costs, capacities, variable types, constraints, and commodities.
- `Problem(problem, network)`: Constructs a new `Problem` instance based on an existing problem but with a different network structure.

# Methods
- `get_network(problem)`: Returns the network of the problem.
- `get_arcs(problem)`: Returns the arcs of the problem's network.
- `get_vertices(problem)`: Returns the vertices of the problem's network.
- `get_constraints(problem)`: Returns the constraints of the problem.
- `get_commodities(problem)`: Returns the commodities of the problem.
- `get_cost(problem, arc)`: Returns the cost of an arc.
- `get_cost(problem, path)`: Returns the cost of a path.
- `get_capacity(problem, arc)`: Returns the capacity of an arc.
- `get_var_type(problem, arc)`: Returns the variable type of an arc.
- `get_constr_coeff_list(problem, arc)`: Returns the list of constraint coefficients for an arc.
- `push_constraint!(problem, constraint)`: Adds a new constraint to the problem.
- `pop_constraint!(problem)`: Removes the most recently added constraint from the problem.
- `_get_arc_to_side_constr_coeffs(arcs, constraints)`: Internal function to initialize the mapping of arcs to their side constraint coefficients.
- `is_problem_integer(problem)`: Returns true if the objective is integer for any feasible solution satisfying integrality constraints.
- `filter_arcs(problem, pred)`: Returns a new instance of `Problem` where only the arcs satisfying the predicate `pred` are kept.
"""
struct Problem
    # input fields
    network::Network
    objective_function::ObjectiveFunction
    arc_to_capacity_map::IndexedMap{Arc,Float64}
    arc_to_var_type_map::IndexedMap{Arc,VarType}
    constraints::Vector{Constraint}
    commodities::Vector{Commodity}

    # aux fields
    arc_to_side_constr_coeffs::LinkedListMap{Tuple{Int,Float64}}

    function Problem(
        network::Network,
        arc_to_cost::Function,
        arc_to_capacity::Function,
        arc_to_var_type::Function,
        constraints::Vector{Constraint},
        commodities::Vector{Commodity},
    )
        arcs = get_arcs(network)
        objective_function = ObjectiveFunction(arcs, arc_to_cost)
        arc_to_capacity_map = IndexedMap{Arc,Float64}(arcs, arc_to_capacity; default = Inf)
        arc_to_var_type_map = IndexedMap{Arc,VarType}(
            arcs, arc_to_var_type; default = CONTINUOUS
        )

        arc_to_side_constr_coeffs = _get_arc_to_side_constr_coeffs(
            get_arcs(network), constraints
        )

        return new(
            network,
            objective_function,
            arc_to_capacity_map,
            arc_to_var_type_map,
            constraints,
            commodities,
            arc_to_side_constr_coeffs,
        )
    end

    function Problem(problem::Problem, network::Network)
        return new(
            network,
            problem.objective_function,
            problem.arc_to_capacity_map,
            problem.arc_to_var_type_map,
            problem.constraints,
            problem.commodities,
            problem.arc_to_side_constr_coeffs,
        )
    end
end

get_network(problem::Problem) = problem.network
get_arcs(problem::Problem) = get_arcs(get_network(problem))
get_vertices(problem::Problem) = get_vertices(get_network(problem))
get_constraints(problem::Problem) = problem.constraints
get_commodities(problem::Problem) = problem.commodities

get_cost(problem::Problem, arc::Arc) = get_cost(problem.objective_function, arc)
get_cost(problem::Problem, path::Path) = get_cost(problem.objective_function, path)
get_capacity(problem::Problem, arc::Arc) = problem.arc_to_capacity_map[arc]
has_capacity(problem::Problem, arc::Arc) = !isinf(problem.arc_to_capacity_map[arc])

function get_var_type(problem::Problem, arc::Arc)
    return problem.arc_to_var_type_map[arc]
end

function get_constr_coeff_list(problem::Problem, arc::Arc)
    return problem.arc_to_side_constr_coeffs[arc.index]
end

function push_constraint!(problem::Problem, constraint::Constraint)
    push!(problem.constraints, constraint)
    push_constraint!(problem.arc_to_side_constr_coeffs, constraint)
    return nothing
end

function pop_constraint!(problem::Problem)
    constraint = pop!(problem.constraints)
    pop!(problem.arc_to_side_constr_coeffs, pair -> pair[1] == constraint.index)
    return nothing
end

function _get_arc_to_side_constr_coeffs(arcs, constraints)
    num_arcs = length(arcs)
    output = LinkedListMap{Tuple{Int,Float64}}(num_arcs)

    for constr in constraints
        push_constraint!(output, constr)
    end
    return output
end

"""
    is_problem_integer(problem::Problem) -> Bool

Determines whether the problem has an integer objective function for any feasible solution that meets all integrality constraints on the variables.
"""
function is_problem_integer(problem::Problem)
    if !is_objective_integer(problem.objective_function)
        return false
    end
    for arc in get_arcs(problem)
        if !iszero(get_cost(problem, arc)) && get_var_type(problem, arc) == CONTINUOUS
            return false
        end
    end
    return true
end

"""
    filter_arcs(problem::Problem, predicate::Function) -> Problem

Creates a new `Problem` instance by filtering out arcs in the original problem's network that do not satisfy a given predicate function.
"""
function filter_arcs(problem::Problem, pred::Function)
    return Problem(problem, filter_arcs(get_network(problem), pred))
end
