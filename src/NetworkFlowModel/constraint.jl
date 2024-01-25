@enum ConstraintType GEQ LEQ EQ

struct Constraint
    index::Int
    arc_to_coefficient::Dict{Arc,Float64}
    constraint_type::ConstraintType
    RHS::Float64 # right-hand side coefficient
    violation_penalty_cost::Float64
end

function get_coefficient(constraint::Constraint, arc::Arc)
    return get(constraint.arc_to_coefficient, arc, 0.0)
end

function get_arc_coeff_list(
    constraint::Constraint; is_arc_available::Function = arc -> true
)
    return [
        (arc, coeff) for (arc, coeff) in constraint.arc_to_coefficient if
        is_arc_available(arc) && !iszero(coeff)
    ]
end

function push_constraint!(
    arc_to_side_constr_coeffs::LinkedListMap{Tuple{Int,Float64}}, constr::Constraint
)
    constr_index = constr.index
    for (arc, coeff) in NetworkFlowModel.get_arc_coeff_list(constr)
        add_value!(arc_to_side_constr_coeffs, arc.index, (constr_index, coeff))
    end
    return nothing
end
