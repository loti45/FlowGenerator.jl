function get_intermediate_vertices(network::Network)
    return [
        vertex for vertex in get_vertices(network) if
        vertex != get_source(network) && vertex != get_sink(network)
    ]
end

function build_vertex_to_outgoing_arcs_map(vertices::Vector{Vertex}, arcs::Vector{Arc})
    num_vertices = length(vertices)
    output = LinkedListMap{Arc}(num_vertices)
    for arc in arcs
        for (tail, _) in get_tail_multiplier_list(arc)
            add_value!(output, tail.index, arc)
        end
    end
    return output
end

"""
    get_vertices(arc::Arc)

Return all vertices in the arc.
"""
function get_vertices(arc::Arc)
    output = Vertex[]
    push!(output, arc.head)
    for (tail, _) in get_tail_multiplier_list(arc)
        push!(output, tail)
    end
    return output
end

"""
    get_vertices(arcs::Vector{Arc})

Return all vertices in the list of arcs.
"""
function get_vertices(arcs::Vector{Arc})
    output = Set{Vertex}()
    for arc in arcs
        union!(output, get_vertices(arc))
    end
    return collect(output)
end
