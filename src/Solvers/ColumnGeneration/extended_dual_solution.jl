# Dual solution with additional information mainly used for pricing and variable fixing.
mutable struct ExtendedDualSolution
    dual_solution::Union{DualSolution,Nothing}
    problem::NetworkFlowModel.Problem
    commodity_to_shortest_path_generator::Dict{
        Commodity,ShortestPathSolver.ShortestPathGenerator
    }
    commodity_to_shortest_path_solution::Dict{
        Commodity,ShortestPathSolver.ShortestPathSolution
    }
    arc_to_reduced_cost::IndexedMap{Arc,Float64} # Auxiliary map that's re-populated at each pricing iteration
    dual_bound::Float64

    function ExtendedDualSolution(problem::NetworkFlowModel.Problem)
        commodity_to_shortest_path_generator = Dict(
            commodity => ShortestPathSolver.build_shortest_path_generator(
                problem.network, commodity.source, commodity.sink
            ) for commodity in get_commodities(problem)
        )
        return new(
            nothing,
            problem,
            commodity_to_shortest_path_generator,
            Dict(),
            IndexedMap{Arc,Float64}(get_arcs(problem); default = Inf),
            Inf,
        )
    end
end

function get_dual_bound(eds::ExtendedDualSolution)
    return eds.dual_bound
end

# Update extended dual solution with new dual solution.
function update_with_new_dual(
    extended_dual_solution::ExtendedDualSolution, dual_solution::DualSolution
)
    extended_dual_solution.dual_solution = dual_solution
    _fill_arc_to_reduced_cost_map!(extended_dual_solution)

    for commodity in get_commodities(extended_dual_solution.problem)
        shortest_path_generator = extended_dual_solution.commodity_to_shortest_path_generator[commodity]
        solution = ShortestPathSolver.generate_shortest_path(
            get_network(extended_dual_solution.problem),
            extended_dual_solution.arc_to_reduced_cost;
            solver = shortest_path_generator,
        )
        extended_dual_solution.commodity_to_shortest_path_solution[commodity] = solution
    end

    _compute_lagrangian_dual_bound(extended_dual_solution)
    return nothing
end

# having this fill function separated, helps Julia with compile optimization
function _fill_arc_to_reduced_cost_map!(extended_dual_solution::ExtendedDualSolution)
    return NetworkFlowModel.fill_arc_to_reduced_cost_map!(
        extended_dual_solution.arc_to_reduced_cost,
        extended_dual_solution.problem,
        extended_dual_solution.dual_solution,
    )
end

# Computes Lagrangian dual bound.
# Assumption: problem is minimization
# Commodity constraints are not dualized. Instead, they determine thw flow for each commodity.
function _compute_lagrangian_dual_bound(eds::ExtendedDualSolution) # TODO : refactor implementation
    dual_obj = NetworkFlowModel.get_obj_val(eds.problem, eds.dual_solution)

    # These values are discounted since the commodity demand/capacity constraints are not dualized
    dual_obj -= sum(
        eds.dual_solution.commodity_to_demand_dual_map[commodity] * commodity.demand for
        commodity in get_commodities(eds.problem);
        init = 0.0,
    )
    dual_obj -= sum(
        eds.dual_solution.commodity_to_capacity_dual_map[commodity] * commodity.capacity for
        commodity in get_commodities(eds.problem);
        init = 0.0,
    )

    function commodity_solution(commodity)
        cost = _get_min_path_cost(eds, commodity)

        # Choose flow quantity that's more attractive, considering it's a minimization problem
        flow = cost < 0 ? commodity.capacity : commodity.demand

        return cost * flow
    end

    rc_sum = sum(
        commodity_solution(commodity) for commodity in get_commodities(eds.problem),
        init in 0.0
    )
    eds.dual_bound = dual_obj + rc_sum
    return nothing
end

function _get_min_path_cost(eds::ExtendedDualSolution, commodity::Commodity)
    return ShortestPathSolver.get_optimal_value_from_source(
        eds.commodity_to_shortest_path_solution[commodity], commodity.sink
    )
end

# Returns a map from each arc to the sum of the dual bound and the reduced cost of sending one unit of flow through the arc
# These values are relevant for reduced-cost variable-fixing
function get_arc_to_min_obj_val(eds::ExtendedDualSolution)
    dual_bound = get_dual_bound(eds)

    is_hyper_graph = NetworkFlowModel.is_hyper_graph(get_network(eds.problem))
    min_obj_val = arc -> if get_var_type(eds.problem, arc) == INTEGER && !is_hyper_graph
        dual_bound + get_min_reduced_cost_in_a_commodity(eds, arc)
    else
        dual_bound
    end

    arc_to_min_obj_val = IndexedMap{Arc,Float64}(
        get_arcs(eds.problem), min_obj_val; default = -Inf
    )

    return arc_to_min_obj_val
end
function get_min_reduced_cost_in_a_commodity(eds::ExtendedDualSolution, arc::Arc)
    return minimum(
        ShortestPathSolver.get_min_unit_flow_cost(sol, arc) for
        sol in values(eds.commodity_to_shortest_path_solution);
        init = Inf,
    )
end
