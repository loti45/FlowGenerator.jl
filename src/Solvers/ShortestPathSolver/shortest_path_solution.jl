"""
    struct Label

Represents a label in the shortest path computation.

# Fields
- `value::Float64`: The cost to reach the node this label is associated with.
- `entering_arc::Arc`: The arc through which this node was reached.
- `min_hops::Int`: The minimum number of arcs required to generate this label.
"""
struct Label
    value::Float64
    entering_arc::Arc
    min_hops::Int
end

"""
    mutable struct ShortestPathSolution

Stores the state necessary for representing a set of solutions of a shortest path computation.

# Fields
- `forward_vertex_to_label::IndexedMap{Vertex,Label}`: Mapping from vertices to labels for forward search from source to each vertex.
- `backward_vertex_to_label::IndexedMap{Vertex,Label}`: Mapping from vertices to labels for backward search from sink to each vertex.
- `arc_to_cost::IndexedMap{Arc,Float64}`: Mapping from arcs to their associated costs.
- `is_hyper_graph::Bool`: Flag indicating if the solution is for a hypergraph. In case this is true, no backward computation has been done.

# Constructor
- `ShortestPathSolution(network::Network)`: Initializes the solution with default labels and inf costs for a given network.
"""
struct ShortestPathSolution
    forward_vertex_to_label::IndexedMap{Vertex,Label}
    backward_vertex_to_label::IndexedMap{Vertex,Label}
    arc_to_cost::IndexedMap{Arc,Float64}
    is_hyper_graph::Bool

    function ShortestPathSolution(network::Network)
        arcs = get_arcs(network)
        vertices = get_vertices(network)
        forward_vertex_to_label = IndexedMap{Vertex,Label}(
            vertices; default = Label(Inf, DUMMY_ARC, 0)
        )
        backward_vertex_to_label = IndexedMap{Vertex,Label}(
            vertices; default = Label(Inf, DUMMY_ARC, 0)
        )
        arc_to_cost = IndexedMap{Arc,Float64}(arcs; default = Inf)

        return new(
            forward_vertex_to_label,
            backward_vertex_to_label,
            arc_to_cost,
            is_hyper_graph(network),
        )
    end
end

"""
    get_optimal_path(solution::ShortestPathSolution, sink::Vertex) -> Path

Retrieve the optimal path from the source to the specified sink vertex using the shortest path solution data.
"""
function get_optimal_path(solution::ShortestPathSolution, sink::Vertex)
    get_best_incoming_arc(vertex) = solution.forward_vertex_to_label[vertex].entering_arc
    shortest_path = Path(
        get_path_from_source_to_vertex(get_best_incoming_arc, sink; multiplier = 1.0)
    )
    return shortest_path
end

"""
    get_optimal_value_from_source(solution::ShortestPathSolution, vertex::Vertex) -> Float64

Return the optimal value (cost) of reaching a specified vertex from the source vertex using the shortest path solution data.
"""
function get_optimal_value_from_source(solution::ShortestPathSolution, vertex::Vertex)
    return solution.forward_vertex_to_label[vertex].value
end

"""
    get_min_unit_flow_cost(solution::ShortestPathSolution, arc::Arc) -> Float64

Calculate the minimum flow cost in a path where the flow on `arc` is one unit.
This function is not compatible with hyper-graphs.

# Returns
- `Float64`: The minimum unit flow cost for the specified arc.
"""
function get_min_unit_flow_cost(solution::ShortestPathSolution, arc::Arc)
    if solution.is_hyper_graph
        throw(ArgumentError("Not implemented for hyper graphs"))
    end
    return sum(
               solution.forward_vertex_to_label[tail].value * multiplier for
               (tail, multiplier) in get_tail_multiplier_list(arc)
           ) +
           solution.backward_vertex_to_label[arc.head].value +
           get_cost(solution, arc)
end

"""
    get_min_unit_flow_path(solution::ShortestPathSolution, arc::Arc) -> Path

Obtain the path with the minimum unit flow cost for a given `arc`.
This function does not support hyper-graphs and will throw an error if used in such context.

# Returns
- `Path`: The path corresponding to the minimum unit flow cost of the `arc`.
"""
function get_min_unit_flow_path(solution::ShortestPathSolution, arc::Arc)
    if solution.is_hyper_graph
        throw(ArgumentError("Not implemented for hyper graphs"))
    end

    @assert arc != DUMMY_ARC

    get_incoming_arc = vertex -> solution.forward_vertex_to_label[vertex].entering_arc
    get_outgoing_arc = vertex -> solution.backward_vertex_to_label[vertex].entering_arc

    arc_to_multiplicity = get_path_from_vertex_to_sink(get_outgoing_arc, arc.head)
    arc_mult = 1.0
    for (_arc, multiplicity) in arc_to_multiplicity
        if arc.head == _arc.tail
            arc_mult *= multiplicity * _arc.multiplier
        end
    end

    @assert !haskey(arc_to_multiplicity, arc) # otherwise there are cycles
    arc_to_multiplicity[arc] = arc_mult

    from_source = get_path_from_source_to_vertex(
        get_incoming_arc, arc.tail; multiplier = arc_mult * arc.multiplier
    )

    for (arc, mult) in from_source
        arc_to_multiplicity[arc] = get(arc_to_multiplicity, arc, 0.0) + mult
    end

    return Path(arc_to_multiplicity)
end

function get_path_from_source_to_vertex(
    get_incoming_arc::Function, vertex::Vertex; multiplier
)
    output = Dict{Arc,Float64}()

    function dfs(current_node, multiplier)
        arc = get_incoming_arc(current_node)
        if arc == DUMMY_ARC
            return nothing
        end
        output[arc] = get(output, arc, 0.0) + multiplier
        for (tail, mult) in get_tail_multiplier_list(arc)
            dfs(tail, multiplier * mult)
        end
    end

    dfs(vertex, multiplier)

    return output
end

function get_path_from_vertex_to_sink(get_outgoing_arc::Function, vertex::Vertex)
    output = Dict{Arc,Float64}()

    function dfs(current_node)
        arc = get_outgoing_arc(current_node)
        if get_outgoing_arc(current_node) == DUMMY_ARC
            return 1.0
        else
            multiplier = dfs(arc.head)
            output[arc] = get(output, arc, 0.0) + multiplier
            return multiplier * arc.multiplier
        end
    end

    dfs(vertex)

    return output
end

function NetworkFlowModel.get_cost(solution::ShortestPathSolution, arc::Arc)
    return solution.arc_to_cost[arc]
end

function NetworkFlowModel.get_cost(solution::ShortestPathSolution, path::Path)
    return sum(
        get_cost(solution, arc) * mult for (arc, mult) in get_arc_to_multiplicity(path);
        init = 0.0,
    )
end
