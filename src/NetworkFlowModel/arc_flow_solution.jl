"""
    struct ArcFlowSolution

A solution object for network flow problems that maps arcs to their flows.

# Fields
- `arc_to_flow_map::Dict{Arc,Float64}`: A dictionary that maps `Arc` objects to `Float64` flow values.
- `source::Vertex`: The source of the flow.
- `sink::Vertex`: The destination of of the flow.

# Constructor
    ArcFlowSolution(c::Commodity)

Constructs an `ArcFlowSolution` with an empty flow map and specified source and sink vertices based on a given `Commodity`.
"""
struct ArcFlowSolution
    arc_to_flow_map::Dict{Arc,Float64}
    source::Vertex
    sink::Vertex
end

ArcFlowSolution(c::Commodity) = ArcFlowSolution(Dict(), c.source, c.sink)

"""
    get_incoming_flow(arc_flow_solution::ArcFlowSolution, vertex::Vertex)

Returns the total incoming flow to a specified vertex in an `ArcFlowSolution`.
"""
function get_incoming_flow(arc_flow_solution::ArcFlowSolution, vertex::Vertex)
    return sum(
        flow for (arc, flow) in arc_flow_solution.arc_to_flow_map if arc.head == vertex;
        init = 0.0,
    )
end

"""
    is_integrality_feasible(problem::Problem, solution::ArcFlowSolution)

Checks if flow integrality of an `ArcFlowSolution` is satisfied for a given `Problem`.

# Returns
- `true` if the solution is integrality feasible, `false` otherwise.
"""
function is_integrality_feasible(problem::Problem, solution::ArcFlowSolution)
    return all(
        isinteger(flow) || get_var_type(problem, arc) != INTEGER for
        (arc, flow) in solution.arc_to_flow_map
    )
end

"""
    get_flow_conservation_balance(sol::ArcFlowSolution)

Calculates the flow conservation balance for each vertex in an `ArcFlowSolution`.

# Returns
- A dictionary mapping each vertex to its flow conservation balance.
"""
function get_flow_conservation_balance(sol::ArcFlowSolution)
    return get_flow_conservation_balance(sol.arc_to_flow_map)
end

"""
    get_flow_conservation_balance(arc_to_flow_map::Dict{Arc,Float64})

Calculates the flow conservation balance for each vertex based on a given `arc_to_flow_map`.

# Returns
- A dictionary mapping each vertex to its flow conservation balance.
"""
function get_flow_conservation_balance(arc_to_flow_map::Dict{Arc,Float64})
    vertex_to_flow_balance = Dict{Vertex,Float64}()
    for (arc, flow) in arc_to_flow_map
        vertex_to_flow_balance[arc.head] = get(vertex_to_flow_balance, arc.head, 0.0) + flow
        for (tail, multiplier) in get_tail_multiplier_list(arc)
            vertex_to_flow_balance[tail] =
                get(vertex_to_flow_balance, tail, 0.0) - flow * multiplier
        end
    end
    return vertex_to_flow_balance
end

"""
    is_flow_conservation_feasible(sol::ArcFlowSolution)

Checks if flow conservation is feasible for an `ArcFlowSolution`.

Flow conservation is feasible if the flow conservation balance of all intermediate nodes is zero

# Returns
- `true` if flow conservation is feasible, `false` otherwise.
"""
function is_flow_conservation_feasible(sol::ArcFlowSolution)
    flow_conservation_balance = get_flow_conservation_balance(sol)
    return all(
        iszero(flow_conservation_balance[vertex]) for
        vertex in keys(flow_conservation_balance) if
        vertex != sol.source && vertex != sol.sink
    )
end
