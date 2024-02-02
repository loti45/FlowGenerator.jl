struct HyperTree
    arc_to_multiplicity::Dict{Arc,Float64}
end

Base.:(==)(t1::HyperTree, t2::HyperTree) = t1.arc_to_multiplicity == t2.arc_to_multiplicity
Base.hash(t::HyperTree, h::UInt) = hash(t.arc_to_multiplicity, h)

get_arc_to_multiplicity(t::HyperTree) = t.arc_to_multiplicity
