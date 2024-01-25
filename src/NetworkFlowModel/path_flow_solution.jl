struct PathFlowSolution
    path_to_flow_map::Dict{Path,Float64}
    source::Vertex
    sink::Vertex
end

"""
    get_path_to_flow_map(sol::PathFlowSolution)

Get the path to flow map in a PathFlowSolution.
"""
get_path_to_flow_map(sol::PathFlowSolution) = sol.path_to_flow_map
"""
    get_path_flow(sol::PathFlowSolution, path::Path)

Get the flow associated with a specific path in a PathFlowSolution.
If the path is not present in the solution, returns 0.0.
"""
get_path_flow(sol::PathFlowSolution, path::Path) = get(sol.path_to_flow_map, path, 0.0)

"""
    convert_to_path_flow_solution(network::Network, arc_flow_solution::ArcFlowSolution)

Convert an ArcFlowSolution to a PathFlowSolution using a flow decomposition algorithm.
"""
function convert_to_path_flow_solution(network::Network, arc_flow_solution::ArcFlowSolution)
    path_flows = Dict()
    flow = copy(arc_flow_solution.arc_to_flow_map)

    while true
        path = find_path(
            network, arc_flow_solution.source, arc_flow_solution.sink, a -> get(flow, a, 0)
        )

        if isnothing(path)
            break
        end

        max_flow = compute_max_feasible_flow(flow, path)

        for (arc, mult) in get_arc_to_multiplicity(path)
            flow[arc] -= max_flow * mult
        end

        path_flows[path] = get(path_flows, path, 0.0) + max_flow
    end

    return PathFlowSolution(path_flows, arc_flow_solution.source, arc_flow_solution.sink)
end

"""
    find_path(network::Network, source::Vertex, sink::Vertex, arc_to_flow::Function)

Returns a path from source to sink in a network with positive flow capacity.
If no such path exists, returns `nothing`.
"""
function find_path(network::Network, source::Vertex, sink::Vertex, arc_to_flow::Function)
    function find_path_recursion(current_node::Vertex; arc_stack = Arc[])
        if current_node == sink
            return arc_stack
        end
        candidate_arcs = get_outgoing_arcs(network, current_node)
        arc = get_arc_with_max_flow(candidate_arcs, arc_to_flow)
        if isnothing(arc) || iszero(arc_to_flow(arc))
            return nothing
        end
        push!(arc_stack, arc)
        return find_path_recursion(arc.head; arc_stack)
    end

    arcs = find_path_recursion(source)

    if isnothing(arcs)
        return nothing
    end

    return Path(arcs)
end

function get_arc_with_max_flow(arcs, arc_to_flow::Function)
    output = nothing
    for outgoing in arcs
        if isnothing(output) || arc_to_flow(outgoing) > arc_to_flow(output)
            output = outgoing
        end
    end
    return output
end

function compute_max_feasible_flow(arc_to_flow::Dict{Arc,Float64}, path::Path)
    return minimum(arc_to_flow[arc] / m for (arc, m) in get_arc_to_multiplicity(path))
end
