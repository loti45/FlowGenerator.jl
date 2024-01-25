"""
    mutable struct ShortestPathGenerator

A structure to accelerate the shortest path computation in networks by reusing a precomputed topologically sorted list of arcs and updating the solution object across calls.

Storing the pre-sorted list of arcs is particularly beneficial when shortest path computations are frequently repeated with varying costs, as in the pricing solution of column generation for large-scale problems.

# Fields
- `top_sorted_arc_list::Vector{Arc}`: List of arcs already sorted by topological order.
- `source::Vertex`: Source vertex for the shortest path computation.
- `sink::Vertex`: Sink (destination) vertex for the shortest path computation.
- `solution::ShortestPathSolution`: Reusable object that holds the current shortest path solution. Reusing the solution object avoids inneficiencies due to memory allocation in huge problems.
"""
mutable struct ShortestPathGenerator
    top_sorted_arc_list::Vector{Arc}
    source::Vertex
    sink::Vertex
    solution::ShortestPathSolution
end

"""
    build_shortest_path_generator(network::Network, source::Vertex, sink::Vertex) -> ShortestPathGenerator

Constructs a `ShortestPathGenerator` instance by creating a topologically sorted list of arcs from the network and initializing an empty shortest path solution.
"""
function build_shortest_path_generator(network::Network, source::Vertex, sink::Vertex)
    top_sorted_arc_list = construct_sorted_arc_list(
        network, source; array_size = length(get_arcs(network))
    )

    solution = ShortestPathSolution(network)
    return ShortestPathGenerator(top_sorted_arc_list, source, sink, solution)
end

# Function to construct a list of arcs sorted topologically
function construct_sorted_arc_list(network, source; array_size)
    sorted_vertices = topological_sort(network, source)

    top_sorted_arc_list = Vector{Arc}()

    for vertex in sorted_vertices
        for arc in get_outgoing_arcs(network, vertex)
            push!(top_sorted_arc_list, arc)
        end
    end

    return top_sorted_arc_list
end

"""
    generate_shortest_path(network::Network, source::Vertex, sink::Vertex, arc_to_cost::AbstractDict) -> ShortestPathSolution

Generates the shortest path solution for a given network from a source to a sink, using specific arc costs. Builds a ShortestPathGenerator internally.

# Returns
- `ShortestPathSolution`: The shortest path solution found by the solver.
"""
function generate_shortest_path(
    network::Network, source::Vertex, sink::Vertex, arc_to_cost::AbstractDict
)
    shortest_path_generator = build_shortest_path_generator(network, source, sink)
    return generate_shortest_path(network, arc_to_cost; solver = shortest_path_generator)
end

"""
    generate_shortest_path(network::Network, arc_to_cost::AbstractDict; solver::ShortestPathGenerator) -> ShortestPathSolution

Generates the shortest path solution for a given network using a specific ShortestPathGenerator.

# Returns
- `ShortestPathSolution`: The shortest path solution found by the solver.
"""
function generate_shortest_path(
    network::Network, arc_to_cost::AbstractDict; solver::ShortestPathGenerator
)
    sol = solver.solution

    reset!(sol.forward_vertex_to_label)
    reset!(sol.backward_vertex_to_label)

    sol.forward_vertex_to_label[solver.source] = Label(0.0, DUMMY_ARC, 0)

    for arc in solver.top_sorted_arc_list
        solver.solution.arc_to_cost[arc] = arc_to_cost[arc]
    end

    # forward computation
    for arc in solver.top_sorted_arc_list
        #        label = sol.forward_vertex_to_label[arc.tail]
        label = v -> sol.forward_vertex_to_label[v]
        candidate_cost =
            arc_to_cost[arc] +
            get_value_sum(sol.forward_vertex_to_label, get_tail_multiplier_list(arc))
        min_hops = get_min_hop_sum(
            sol.forward_vertex_to_label, get_tail_multiplier_list(arc)
        )
        candidate_label = Label(candidate_cost, arc, min_hops + 1)
        head_label = sol.forward_vertex_to_label[arc.head]

        if is_dominant(candidate_label, head_label)
            sol.forward_vertex_to_label[arc.head] = candidate_label
        end
    end

    sol.backward_vertex_to_label[solver.sink] = Label(0.0, DUMMY_ARC, 0)

    # backward computation
    if !is_hyper_graph(network)
        for arc in Iterators.reverse(solver.top_sorted_arc_list)
            label = sol.backward_vertex_to_label[arc.head]
            candidate_cost = (label.value + arc_to_cost[arc]) / arc.multiplier
            candidate_label = Label(candidate_cost, arc, label.min_hops + 1)

            tail_label = sol.backward_vertex_to_label[arc.tail]
            if is_dominant(candidate_label, tail_label)
                sol.backward_vertex_to_label[arc.tail] = candidate_label
            end
        end
    end

    return sol
end

# Modularized for improved performance
function get_value_sum(vertex_to_label, vertex_multiplier_list)
    return sum(
        vertex_to_label[tail].value * multiplier for
        (tail, multiplier) in vertex_multiplier_list
    )
end

# Modularized for improved performance
function get_min_hop_sum(vertex_to_label, vertex_multiplier_list)
    return sum(
        vertex_to_label[tail].min_hops for (tail, multiplier) in vertex_multiplier_list
    )
end

# returns true if l1 dominates l2
function is_dominant(l1::Label, l2::Label)
    return l1.value < l2.value || (l1.value <= l2.value && l1.min_hops < l2.min_hops)
end
