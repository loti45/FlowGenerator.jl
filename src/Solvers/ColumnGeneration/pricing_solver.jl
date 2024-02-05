struct PricingSolver
    problem::NetworkFlowModel.Problem
    params::ColumnGenerationParams
    extended_dual_solution::ExtendedDualSolution

    function PricingSolver(
        problem::NetworkFlowModel.Problem, params::ColumnGenerationParams
    )
        return new(problem, params, ExtendedDualSolution(problem))
    end
end

function pricing!(pricing_solver::PricingSolver, primal_solution, dual_solution)
    update_with_new_dual(pricing_solver.extended_dual_solution, dual_solution)
    columns = MipModel.Column[]

    for commodity in get_commodities(pricing_solver.problem)
        for path in _generate_columns!(pricing_solver, commodity)
            basis_kind = pricing_solver.params.basis_kind
            if basis_kind == PathFlowBasis()
                push!(columns, MipModel.Column(pricing_solver.problem, path, commodity))
            elseif basis_kind == ArcFlowBasis()
                for arc in get_arcs(path)
                    push!(columns, MipModel.Column(pricing_solver.problem, arc, commodity))
                end
            else
                throw(ArgumentError("Unsupported basis kind $basis_kind"))
            end
        end
    end

    return columns
end

function _generate_columns!(pricing_solver::PricingSolver, commodity::Commodity)
    if isempty(get_arcs(pricing_solver.problem))
        return []
    end
    dual_solution = pricing_solver.extended_dual_solution.dual_solution
    commodity_dual = NetworkFlowModel.get_commodity_dual(dual_solution, commodity)
    shortest_path_solution = pricing_solver.extended_dual_solution.commodity_to_shortest_path_solution[commodity]

    multiple_paths = pricing_solver.params.pricing_kind.pseudo_complementary
    paths = if multiple_paths && !is_hyper_graph(get_network(pricing_solver.problem))
        _get_min_cover_shortest_paths(pricing_solver.problem, shortest_path_solution)
    else
        []
    end

    optimal_path = ShortestPathSolver.get_optimal_path(
        shortest_path_solution, commodity.sink
    )
    push!(paths, optimal_path)

    function reduced_cost(path)
        return get_cost(shortest_path_solution, path) - commodity_dual
    end

    min_rc = if !isempty(paths)
        minimum(reduced_cost.(paths))
    else
        0.0
    end

    filter!(p -> reduced_cost(p) < pricing_solver.params.min_rc_to_stop, paths)

    dual_bound = get_dual_bound(pricing_solver.extended_dual_solution)

    println(
        "+ CG \t | dual bound $(round(dual_bound, digits = 4)) \t| min RC = $(round(min_rc, digits=4)) \t| generated $(length(paths)) paths",
    )

    return paths
end

function _get_min_cover_shortest_paths(
    problem::NetworkFlowModel.Problem,
    shortest_path_solution::ShortestPathSolver.ShortestPathSolution,
)
    side_constr_to_best_arc_and_value = fill(
        (ShortestPathSolver.DUMMY_ARC, Inf), length(get_constraints(problem))
    )

    for arc in get_arcs(get_network(problem))
        min_unit_flow_cost = ShortestPathSolver.get_min_unit_flow_cost(
            shortest_path_solution, arc
        )
        for (constr, _) in NetworkFlowModel.get_constr_coeff_list(problem, arc)
            if side_constr_to_best_arc_and_value[constr.index][2] > min_unit_flow_cost
                side_constr_to_best_arc_and_value[constr.index] = (
                    arc, min_unit_flow_cost
                )
            end
        end
    end

    output_paths = Path[]
    for (arc, _) in side_constr_to_best_arc_and_value
        if arc != ShortestPathSolver.DUMMY_ARC
            path = ShortestPathSolver.get_min_unit_flow_path(shortest_path_solution, arc)
            push!(output_paths, path)
        end
    end

    return output_paths
end
