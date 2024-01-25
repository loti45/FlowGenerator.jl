struct Network
    vertices::Vector{Vertex}
    arcs::Vector{Arc}
    arc_hash::IndexedMap{Arc,Bool}
    vertex_to_outgoing_arcs_map::LinkedListMap{Arc}
    is_hyper_graph::Bool

    function Network(vertices::Vector{Vertex}, arcs::Vector{Arc})
        vertex_to_outgoing_arcs_map = build_vertex_to_outgoing_arcs_map(vertices, arcs)
        arc_hash = IndexedMap{Arc,Bool}(arcs, arc -> true; default = false)
        is_hyper_graph = any(arc -> is_hyper_arc(arc), arcs)
        return new(vertices, arcs, arc_hash, vertex_to_outgoing_arcs_map, is_hyper_graph)
    end
end

"""
new_network(vertices::Vector{Vertex}, arcs::Vector{Arc})

Create a new `Network` object with the given vertices and arcs.
"""
new_network(vertices::Vector{Vertex}, arcs::Vector{Arc}) = Network(vertices, arcs)

"""
get_vertices(network::Network)

Return the list of vertices in the network.
"""
get_vertices(network::Network) = network.vertices

"""
get_arcs(network::Network)

Return the list of arcs in the network.
"""
get_arcs(network::Network) = network.arcs

"""
get_outgoing_arcs(n::Network, v::Vertex)

Return the list of outgoing arcs from a given vertex in the network.
"""
get_outgoing_arcs(n::Network, v::Vertex) = n.vertex_to_outgoing_arcs_map[v.index]

"""
is_hyper_graph(n::Network)

Check if the network is a hypergraph.
"""
is_hyper_graph(n::Network) = n.is_hyper_graph

"""
Base.in(arc::Arc, network::Network)

Check if an arc is in the network.
"""
Base.in(arc::Arc, network::Network) = network.arc_hash[arc]

"""
Base.in(path::Path, network::Network)

Check if a path is in the network.
"""
function Base.in(path::Path, network::Network)
    return all(pair -> pair[1] in network, get_arc_to_multiplicity(path))
end

"""
filter_arcs(network::Network, predicate::Function)

Return a copy of the network with only the arcs that satisfy a given predicate.
"""
function filter_arcs(network::Network, pred::Function)
    return Network(get_vertices(network), filter(pred, get_arcs(network)))
end

"""
topological_sort(network::Network, sources::Vector{Vertex})

Perform a topological sort on the network starting from the given source vertices.
"""
function topological_sort(network::Network, sources::Vector{Vertex})
    visited = IndexedMap{Vertex,Bool}(get_vertices(network); default = false)
    on_stack = IndexedMap{Vertex,Bool}(get_vertices(network); default = false)
    sorted_list = []

    function dfs(vertex)
        if on_stack[vertex]
            throw(ErrorException("Cycle detected"))
        elseif !visited[vertex]
            on_stack[vertex], visited[vertex] = true, true
            foreach(arc -> dfs(arc.head), get_outgoing_arcs(network, vertex))
            push!(sorted_list, vertex)
            on_stack[vertex] = false
        end
    end

    foreach(s -> dfs(s), sources)

    # Reverse the stack to get the topological order from source to sink
    return reverse(sorted_list)
end

topological_sort(network::Network, source::Vertex) = topological_sort(network, [source])
