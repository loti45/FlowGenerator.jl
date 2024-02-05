struct DualSolution
    commodity_to_demand_dual_map::Dict{Commodity,Float64}
    commodity_to_capacity_dual_map::Dict{Commodity,Float64}
    side_constraint_to_dual_map::Dict{Constraint,Float64}
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

"""
    get_commodity_dual(dual_solution::DualSolution, commodity::Commodity)

Get the dual value associated with a commodity.
"""
function get_commodity_dual(dual_solution::DualSolution, commodity::Commodity)
    return dual_solution.commodity_to_demand_dual_map[commodity] +
           dual_solution.commodity_to_capacity_dual_map[commodity]
end
