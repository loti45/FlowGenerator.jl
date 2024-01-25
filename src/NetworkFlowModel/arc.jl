const VertexMult = Tuple{Vertex,Float64}
struct Arc
    index::Int
    tail_multiplier_list::Union{Tuple{VertexMult},Vector{VertexMult}}
    head::Vertex
    function Arc(index::Int, tail_multiplier_list, head::Vertex)
        if length(tail_multiplier_list) == 0
            throw(ArgumentError("Arc must have at least one tail"))
        end
        return new(index, tail_multiplier_list, head)
    end
end

function new_arc(index::Int, tail_multiplier::Tuple{Vertex,Float64}, head::Vertex)
    tail_multiplier_list = ((tail_multiplier[1], tail_multiplier[2]),)
    return Arc(index, tail_multiplier_list, head)
end

function new_arc(index::Int, tail_to_multiplier::Dict{Vertex,Float64}, head::Vertex)
    tail_to_multiplier_list = if length(tail_to_multiplier) == 1
        Tuple((tail, multiplier) for (tail, multiplier) in tail_to_multiplier)
    else
        [(tail, multiplier) for (tail, multiplier) in tail_to_multiplier]
    end
    return Arc(index, tail_to_multiplier_list, head)
end

get_head(arc::Arc) = arc.head
get_tail_multiplier_list(arc::Arc) = arc.tail_multiplier_list
is_hyper_arc(arc::Arc) = length(arc.tail_multiplier_list) > 1

# getproperty 
# if arc : returns only(tail_multiplier)
# return original symbol otherwise
function Base.getproperty(arc::Arc, sym::Symbol) # TODO :  remove
    return if sym == :tail
        only(arc.tail_multiplier_list)[1]
    elseif sym == :multiplier
        only(arc.tail_multiplier_list)[2]
    else
        getfield(arc, sym)
    end
end
