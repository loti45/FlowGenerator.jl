struct DualSolution
    commodity_to_demand_dual_map::Dict{Commodity,Float64}
    commodity_to_capacity_dual_map::Dict{Commodity,Float64}
    side_constraint_to_dual_map::IndexedMap{Constraint,Float64}
    arc_capacity_to_dual_map::Dict{Arc,Float64}
end

"""
    get_obj_val(problem::Problem, dual_solution::DualSolution)

Return objective value of dual solution. Dual feasibility is not taken into account.
"""
function get_obj_val(problem::Problem, dual_solution::DualSolution)
    output = 0.0
    output += sum(
        dual_solution.commodity_to_demand_dual_map[commodity] * commodity.demand for
        commodity in get_commodities(problem);
        init = 0.0,
    )
    output += sum(
        dual_solution.commodity_to_capacity_dual_map[commodity] * commodity.capacity for
        commodity in get_commodities(problem);
        init = 0.0,
    )
    output += sum(
        dual_solution.side_constraint_to_dual_map[constr] * constr.RHS for
        constr in get_constraints(problem);
        init = 0.0,
    )
    output += sum(
        dual_solution.arc_capacity_to_dual_map[arc] * get_capacity(problem, arc) for
        arc in get_arcs(problem) if has_capacity(problem, arc);
        init = 0.0,
    )
    return output
end

"""
    get_side_constraint_dual(dual_solution::DualSolution, constraint::Constraint)

Get the dual value associated with a side constraint.
"""
function get_side_constraint_dual(dual_solution::DualSolution, constraint::Constraint)
    return dual_solution.side_constraint_to_dual_map[constraint]
end

function get_arc_capacity_dual(problem::Problem, dual_solution::DualSolution, arc::Arc)
    return has_capacity(problem, arc) ? dual_solution.arc_capacity_to_dual_map[arc] : 0.0
end

"""
    get_commodity_dual(dual_solution::DualSolution, commodity::Commodity)

Get the dual value associated with a commodity.
"""
function get_commodity_dual(dual_solution::DualSolution, commodity::Commodity)
    return dual_solution.commodity_to_demand_dual_map[commodity] +
           dual_solution.commodity_to_capacity_dual_map[commodity]
end

"""
    fill_arc_to_reduced_cost_map!(arc_to_reduced_cost_map::AbstractDict{Arc,Float64}, problem::Problem, dual_solution::DualSolution)

Fill the `arc_to_reduced_cost_map` with the reduced cost of each arc.
"""
function fill_arc_to_reduced_cost_map!(
    arc_to_reduced_cost_map::AbstractDict{Arc,Float64},
    problem::Problem,
    dual_solution::DualSolution,
)
    for arc in get_arcs(problem)
        arc_to_reduced_cost_map[arc] = get_arc_reduced_cost(
            problem, dual_solution, arc; capacity_dual = 0.0
        )
    end

    for (arc, dual) in dual_solution.arc_capacity_to_dual_map
        arc_to_reduced_cost_map[arc] -= dual
    end

    return nothing
end

"""
    get_arc_reduced_cost(problem::Problem, dual_solution::DualSolution, arc::Arc; capacity_dual = get_arc_capacity_dual(problem, dual_solution, arc))

Get the reduced cost of an arc based on the dual solution. The reduced cost is computed based on side constraint and capacity dual values, but not on commodity and flow conservation dual values.
"""
function get_arc_reduced_cost(
    problem::Problem,
    dual_solution::DualSolution,
    arc::Arc;
    capacity_dual = get_arc_capacity_dual(problem, dual_solution, arc),
)
    return get_cost(problem, arc) - sum(
        coeff * NetworkFlowModel.get_side_constraint_dual(dual_solution, constr) for
        (constr, coeff) in NetworkFlowModel.get_constr_coeff_list(problem, arc);
        init = 0.0,
    ) + capacity_dual
end
