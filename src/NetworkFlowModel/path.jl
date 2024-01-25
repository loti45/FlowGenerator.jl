struct Path
    arc_to_multiplicity::Dict{Arc,Float64}
    function Path(arc_to_multiplicity::Dict{Arc,Float64})
        if !is_path_balanced(arc_to_multiplicity)
            throw(ArgumentError("Path is not balanced"))
        end
        return new(arc_to_multiplicity)
    end

    function Path(arcs::Vector{Arc})
        for i in 1:(length(arcs) - 1)
            if arcs[i].head != arcs[i + 1].tail
                throw(ArgumentError("Invalid arc sequence"))
            end
        end
        arc_to_multiplicity = Dict{Arc,Float64}()
        mult = 1.0
        for i in length(arcs):-1:1
            arc = arcs[i]
            arc_to_multiplicity[arc] = mult
            mult *= arc.multiplier
        end
        return new(arc_to_multiplicity)
    end
end

function new_path(arcs::Vector{Arc})
    for i in 1:(length(arcs) - 1)
        if arcs[i].head != arcs[i + 1].tail
            throw(ArgumentError("Invalid arc sequence"))
        end
    end
    arc_to_multiplicity = Dict{Arc,Float64}()
    mult = 1.0
    for i in length(arcs):-1:1
        arc = arcs[i]
        arc_to_multiplicity[arc] = mult
        mult *= arc.multiplier
    end
    return Path(arc_to_multiplicity)
end

Base.:(==)(p1::Path, p2::Path) = p1.arc_to_multiplicity == p2.arc_to_multiplicity
Base.hash(p::Path, h::UInt) = hash(p.arc_to_multiplicity, h)

function get_arc_to_multiplicity(path::Path)
    return path.arc_to_multiplicity
end

get_multiplicity(path::Path, arc::Arc) = get(path.arc_to_multiplicity, arc, 0.0)

function is_path_balanced(arc_to_multiplicity::Dict{Arc,Float64})
    balance = get_flow_conservation_balance(arc_to_multiplicity)
    non_zero = filter(vertex -> !iszero(balance[vertex]), keys(balance))

    if length(non_zero) == 2
        if all(v -> balance[v] > 0.0, non_zero)
            return false
        elseif !any(v -> balance[v] == 1.0, non_zero)
            return false
        end
        return true
    end
    return isempty(non_zero) # either all zero or two non-zero
end
