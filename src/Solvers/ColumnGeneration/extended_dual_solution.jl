abstract type ExactSubproblemSolver end
abstract type ExactSubproblemSolution end

mutable struct BidirectionalSubproblemSolver <: ExactSubproblemSolver
    problem::NetworkFlowModel.Problem
    commodity_to_shortest_path_generator::Dict{
        Commodity,ShortestPathSolver.ShortestPathGenerator
    }
    arc_to_reduced_cost::IndexedMap{Arc,Float64} # Auxiliary map that's re-populated at each pricing iteration

    function BidirectionalSubproblemSolver(problem::NetworkFlowModel.Problem)
        commodity_to_shortest_path_generator = Dict(
            commodity => ShortestPathSolver.build_shortest_path_generator(
                problem.network, commodity.source, commodity.sink
            ) for commodity in get_commodities(problem)
        )
        return new(
            problem,
            commodity_to_shortest_path_generator,
            IndexedMap{Arc,Float64}(get_arcs(problem); default = Inf),
        )
    end
end

struct BidirectionalSubproblemSolution <: ExactSubproblemSolution
    dual_bound::Float64
    commodity_to_shortest_path_solution::Dict{
        Commodity,ShortestPathSolver.ShortestPathSolution
    }
end

function get_dual_bound(sp_solution::ExactSubproblemSolution)
    return sp_solution.dual_bound
end

# Computes Lagrangian dual bound.
# Assumption: problem is minimization
# Commodity constraints are not dualized. Instead, they determine thw flow for each commodity.
function _compute_lagrangian_dual_bound(dual_solution::DualSolution, sp_solver::BidirectionalSubproblemSolver, get_commodity_min_path_cost::Function) # TODO : refactor implementation
    dual_obj = NetworkFlowModel.get_obj_val(sp_solver.problem, dual_solution)

    # These values are discounted since the commodity demand/capacity constraints are not dualized
    dual_obj -= sum(
        dual_solution.commodity_to_demand_dual_map[commodity] * commodity.demand for
        commodity in get_commodities(sp_solver.problem);
        init = 0.0,
    )
    dual_obj -= sum(
        dual_solution.commodity_to_capacity_dual_map[commodity] * commodity.capacity for
        commodity in get_commodities(sp_solver.problem);
        init = 0.0,
    )

    function commodity_solution(commodity)
        cost = get_commodity_min_path_cost(commodity)

        # Choose flow quantity that's more attractive, considering it's a minimization problem
        flow = cost < 0 ? commodity.capacity : commodity.demand

        return cost * flow
    end

    rc_sum = sum(
        commodity_solution(commodity) for commodity in get_commodities(sp_solver.problem),
        init in 0.0
    )
    return dual_obj + rc_sum
end

# Returns a map from each arc to the sum of the dual bound and the reduced cost of sending one unit of flow through the arc
# These values are relevant for reduced-cost variable-fixing
function get_arc_to_min_obj_val(problem::NetworkFlowModel.Problem, sp_solution::ExactSubproblemSolution)
    dual_bound = get_dual_bound(sp_solution)

    is_hyper_graph = NetworkFlowModel.is_hyper_graph(get_network(problem))
    min_obj_val = arc -> if get_var_type(problem, arc) == INTEGER && !is_hyper_graph
        dual_bound + get_min_reduced_cost_in_a_commodity(sp_solution, arc)
    else
        dual_bound
    end

    arc_to_min_obj_val = IndexedMap{Arc,Float64}(
        get_arcs(problem), min_obj_val; default = -Inf
    )

    return arc_to_min_obj_val
end


function solve!(
    sp_solver::BidirectionalSubproblemSolver, dual_solution::DualSolution
)
    NetworkFlowModel.fill_arc_to_reduced_cost_map!(
        sp_solver.arc_to_reduced_cost,
        sp_solver.problem,
        dual_solution,
    )

    commodity_to_shortest_path_solution = Dict{Commodity,ShortestPathSolver.ShortestPathSolution}()
    for commodity in get_commodities(sp_solver.problem)
        shortest_path_generator = sp_solver.commodity_to_shortest_path_generator[commodity]
        solution = ShortestPathSolver.generate_shortest_path(
            get_network(sp_solver.problem),
            sp_solver.arc_to_reduced_cost;
            solver = shortest_path_generator,
        )
        commodity_to_shortest_path_solution[commodity] = solution
    end

    get_commodity_min_path_cost = commodity -> ShortestPathSolver.get_optimal_value_from_source(
        commodity_to_shortest_path_solution[commodity], commodity.sink
    )

    dual_bound = _compute_lagrangian_dual_bound(dual_solution, sp_solver, get_commodity_min_path_cost)
    return BidirectionalSubproblemSolution(dual_bound, commodity_to_shortest_path_solution)
end

function get_min_reduced_cost_in_a_commodity(sp_solution::BidirectionalSubproblemSolution, arc::Arc)
    return minimum(
        ShortestPathSolver.get_min_unit_flow_cost(sol, arc) for
        sol in values(sp_solution.commodity_to_shortest_path_solution);
        init = Inf,
    )
end
