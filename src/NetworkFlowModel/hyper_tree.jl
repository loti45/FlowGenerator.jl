struct HyperTree
    arc_to_multiplicity::Dict{Arc,Float64}
    head::Vertex
    tail_to_multiplier::Dict{Vertex,Float64}
    function HyperTree(arc_to_multiplicity::Dict{Arc,Float64})
        head = _compute_head(arc_to_multiplicity)
        tail_to_multiplier = _compute_tail_to_multiplier(arc_to_multiplicity)
        tree = new(arc_to_multiplicity, head, tail_to_multiplier)
        _is_hyper_tree_balanced(tree)
        return tree
    end
end

get_arc_to_multiplicity(t::HyperTree) = t.arc_to_multiplicity
get_head(t::HyperTree) = t.head
get_tail_to_multiplier_map(t::HyperTree) = t.tail_to_multiplier

Base.:(==)(t1::HyperTree, t2::HyperTree) = t1.arc_to_multiplicity == t2.arc_to_multiplicity
Base.hash(t::HyperTree, h::UInt) = hash(t.arc_to_multiplicity, h)

# head is the only vertex without outgoing arcs.
function _compute_head(arc_to_multiplicity::Dict{Arc,Float64})
    arcs = collect(keys(arc_to_multiplicity))
    vertex_to_outgoing_arcs = _get_vertex_to_outgoing_arcs_dictionary(arcs)
    return only([v for v in get_vertices(arcs) if length(vertex_to_outgoing_arcs[v]) == 0])
end

# tails are the vertices without incoming arcs.
function _compute_tails(arc_to_multiplicity::Dict{Arc,Float64})
    arcs = collect(keys(arc_to_multiplicity))
    vertex_to_incoming_arcs = _get_vertex_to_incoming_arcs_dictionary(arcs)
    return [v for v in get_vertices(arcs) if length(vertex_to_incoming_arcs[v]) == 0]
end

function _compute_tail_to_multiplier(arc_to_multiplicity::Dict{Arc,Float64})
    tails = _compute_tails(arc_to_multiplicity)
    vertex_to_multiplicity = Dict{Vertex,Float64}(v => 0.0 for v in tails)
    for arc in keys(arc_to_multiplicity)
        for (tail, mult) in get_tail_multiplier_list(arc)
            if tail in tails
                vertex_to_multiplicity[tail] += arc_to_multiplicity[arc] * mult
            end
        end
    end
    return vertex_to_multiplicity
end

# this is different from the one in helpers.jl for performance reasons. This should be more optimized for smaller sets of vertices
function _get_vertex_to_outgoing_arcs_dictionary(arcs::Vector{Arc})
    output = Dict{Vertex,Vector{Arc}}(v => Arc[] for v in get_vertices(arcs))
    for arc in arcs
        for (tail, _) in get_tail_multiplier_list(arc)
            push!(output[tail], arc)
        end
    end
    return output
end

# this is different from the one in helpers.jl for performance reasons. This should be more optimized for smaller sets of vertices
function _get_vertex_to_incoming_arcs_dictionary(arcs::Vector{Arc})
    output = Dict{Vertex,Vector{Arc}}(v => Arc[] for v in get_vertices(arcs))
    for arc in arcs
        push!(output[arc.head], arc)
    end
    return output
end

function _is_hyper_tree_balanced(hyper_tree::HyperTree)
    vertex_to_flow_balance = get_flow_conservation_balance(hyper_tree.arc_to_multiplicity)
    for (vertex, flow_balance) in vertex_to_flow_balance
        if vertex == get_head(hyper_tree)
            if flow_balance != 1.0
                throw(ArgumentError("Head vertex flow balance $flow_balance must be 1.0"))
            end
        elseif vertex in keys(get_tail_to_multiplier_map(hyper_tree))
            if iszero(flow_balance)
                throw(
                    ArgumentError("Tail vertex flow balance $flow_balance must not be 0.0")
                )
            end
        else
            if !iszero(flow_balance)
                throw(
                    ArgumentError(
                        "Flow balance $flow_balance of intermediate vertex must be 0.0"
                    ),
                )
            end
        end
    end
end
