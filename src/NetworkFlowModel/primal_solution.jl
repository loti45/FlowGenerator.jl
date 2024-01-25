struct PrimalSolution
    commodity_to_arc_flow_solution::Dict{Commodity,ArcFlowSolution}
end

function PrimalSolution(problem::Problem)
    commodity_to_empty_sol = Dict(c => ArcFlowSolution(c) for c in get_commodities(problem))
    return PrimalSolution(commodity_to_empty_sol)
end
"""
    get_arc_flow_solution(primal_solution::PrimalSolution, commodity::Commodity)

Return the arc flow solution for a specific commodity in the given primal solution.
"""
function get_arc_flow_solution(primal_solution::PrimalSolution, commodity::Commodity)
    return get(
        primal_solution.commodity_to_arc_flow_solution,
        commodity,
        ArcFlowSolution(commodity),
    )
end

"""
    get_arc_to_flow_map(primal_solution::PrimalSolution, commodity::Commodity)

Return the arc to flow map for a specific commodity in the given primal solution.
"""
function get_arc_to_flow_map(primal_solution::PrimalSolution, commodity::Commodity)
    return primal_solution.commodity_to_arc_flow_solution[commodity].arc_to_flow_map
end

"""
    get_obj_val(problem::Problem, solution::PrimalSolution)

Calculate the objective value of a primal solution for a given problem.
The objective consists of: flow cost and constraint/commodity violation penalty costs
"""
function get_obj_val(problem::Problem, solution::PrimalSolution)
    arc_to_flow_map = get_aggregated_arc_to_flow_map(solution)

    obj_val = 0.0
    obj_val += get_flow_cost(problem, arc_to_flow_map)
    obj_val += get_constraint_violation_cost(problem, arc_to_flow_map)
    obj_val += get_commodity_violation_cost(problem, solution)
    return obj_val
end

"""
    get_flow_cost(problem::Problem, arc_to_flow_map::Dict{Arc,Float64})

Returns the total flow cost for a given problem.
"""
function get_flow_cost(problem::Problem, arc_to_flow_map::Dict{Arc,Float64})
    obj_val = 0.0
    for (arc, flow) in arc_to_flow_map
        obj_val += flow * get_cost(problem, arc)
    end
    return obj_val
end

function get_constraint_violation_cost(problem::Problem, arc_to_flow_map::Dict{Arc,Float64})
    get_violation_cost =
        ctr -> get_violation(ctr, arc_to_flow_map) * ctr.violation_penalty_cost
    return sum(get_violation_cost(ctr) for ctr in get_constraints(problem); init = 0.0)
end

function get_commodity_violation_cost(problem::Problem, primal_solution::PrimalSolution)
    return sum(
        get_violation(commodity, primal_solution) * commodity.violation_penalty_cost for
        commodity in get_commodities(problem)
    )
end

function get_aggregated_arc_to_flow_map(primal_solution::PrimalSolution)
    arc_to_flow_map = Dict{Arc,Float64}()
    for (_, arc_flow_solution) in primal_solution.commodity_to_arc_flow_solution
        for (arc, flow) in arc_flow_solution.arc_to_flow_map
            arc_to_flow_map[arc] = get(arc_to_flow_map, arc, 0.0) + flow
        end
    end
    return arc_to_flow_map
end

function get_violation(constraint::Constraint, arc_to_flow_map::Dict{Arc,Float64})
    diff = constraint.RHS
    for (arc, coefficient) in constraint.arc_to_coefficient
        diff -= coefficient * get(arc_to_flow_map, arc, 0.0)
    end
    return if constraint.constraint_type == GEQ
        max(diff, 0.0)
    elseif constraint.constraint_type == LEQ
        max(-diff, 0.0)
    elseif constraint.constraint_type == EQ
        abs(diff)
    else
        throw(ArgumentError("Invalid constraint type"))
    end
end

function get_violation(commodity::Commodity, primal_solution::PrimalSolution)
    served_flow = get_incoming_flow(
        primal_solution.commodity_to_arc_flow_solution[commodity], commodity.sink
    )
    violation = max(served_flow - commodity.capacity, 0.0)
    violation = max(commodity.demand - served_flow, violation)
    return violation
end

"""
    is_integrality_feasible(problem::Problem, solution::PrimalSolution)

Checks if flow integrality of a `PrimalSolution` is satisfied for a given `Problem`.
"""
function is_integrality_feasible(problem::Problem, solution::PrimalSolution)
    return all(
        is_integrality_feasible(problem, sol) for
        (_, sol) in solution.commodity_to_arc_flow_solution
    )
end
