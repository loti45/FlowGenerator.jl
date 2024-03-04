mutable struct PricingSolver
    problem::NetworkFlowModel.Problem
    params::ColumnGenerationParams
    sp_solver::BidirectionalSubproblemSolver
    sp_solution::Union{ExactSubproblemSolution,Nothing}
    arc_to_reduced_cost::IndexedMap{Arc,Float64} # Auxiliary map that's re-populated at each pricing iteration

    function PricingSolver(
        problem::NetworkFlowModel.Problem, params::ColumnGenerationParams
    )
        return new(
            problem,
            params,
            BidirectionalSubproblemSolver(problem),
            nothing,
            IndexedMap{Arc,Float64}(get_arcs(problem); default = Inf),
        )
    end
end

function pricing!(pricing_solver::PricingSolver, primal_solution, dual_solution)
    NetworkFlowModel.fill_arc_to_reduced_cost_map!(
        pricing_solver.arc_to_reduced_cost, pricing_solver.problem, dual_solution
    )

    pricing_solver.sp_solution = solve!(
        pricing_solver.sp_solver, dual_solution, pricing_solver.arc_to_reduced_cost
    )
    columns = MipModel.Column[]

    for commodity in get_commodities(pricing_solver.problem)
        for path in _generate_columns!(pricing_solver, commodity, dual_solution)
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

function _generate_columns!(
    pricing_solver::PricingSolver, commodity::Commodity, dual_solution::DualSolution
)
    if isempty(get_arcs(pricing_solver.problem))
        return []
    end
    sp_solution = pricing_solver.sp_solution

    multiple_paths = pricing_solver.params.pricing_kind.pseudo_complementary
    paths = if multiple_paths && !is_hyper_graph(get_network(pricing_solver.problem))
        _get_min_cover_shortest_paths(
            pricing_solver.problem,
            arc -> get_shortest_path(sp_solution, commodity, arc),
            arc -> get_shortest_path_cost(sp_solution, commodity, arc),
        )
    else
        []
    end

    optimal_path = get_optimal_path(pricing_solver.sp_solution, commodity)
    push!(paths, optimal_path)

    min_rc = if !isempty(paths)
        minimum(
            get_reduced_cost(path, pricing_solver, commodity, dual_solution) for
            path in paths
        )
    else
        0.0
    end

    filter!(
        p ->
            get_reduced_cost(p, pricing_solver, commodity, dual_solution) <
            pricing_solver.params.min_rc_to_stop,
        paths,
    )

    dual_bound = get_dual_bound(pricing_solver.sp_solution)

    println(
        "+ CG \t | dual bound $(round(dual_bound, digits = 4)) \t| min RC = $(round(min_rc, digits=4)) \t| generated $(length(paths)) paths",
    )

    return paths
end

function get_reduced_cost(
    path::Path,
    pricing_solver::PricingSolver,
    commodity::Commodity,
    dual_solution::DualSolution;
    sp_solution = pricing_solver.sp_solution,
)
    reduced_cost = sum(
        pricing_solver.arc_to_reduced_cost[arc] * multiplicity for
        (arc, multiplicity) in get_arc_to_multiplicity(path)
    )
    reduced_cost -= if get_head(path) == get_sink(commodity)
        NetworkFlowModel.get_commodity_dual(dual_solution, commodity)
    else
        get_node_potential(sp_solution, get_head(path))
    end

    for (tail, multiplier) in get_tail_to_multiplier_map(path)
        if tail != get_source(commodity)
            reduced_cost += get_node_potential(sp_solution, tail) * multiplier
        end
    end
    return reduced_cost
end

function _get_min_cover_shortest_paths(
    problem::NetworkFlowModel.Problem,
    arc_to_shortest_path::Function,
    arc_to_shortest_path_cost::Function,
)
    side_constr_to_best_arc_and_value = fill(
        (ShortestPathSolver.DUMMY_ARC, Inf), length(get_constraints(problem))
    )

    for arc in get_arcs(get_network(problem))
        shortest_path_cost = arc_to_shortest_path_cost(arc)
        for (constr, _) in NetworkFlowModel.get_constr_coeff_list(problem, arc)
            if side_constr_to_best_arc_and_value[constr.index][2] > shortest_path_cost
                side_constr_to_best_arc_and_value[constr.index] = (arc, shortest_path_cost)
            end
        end
    end

    output_paths = Path[]
    for (arc, _) in side_constr_to_best_arc_and_value
        if arc != ShortestPathSolver.DUMMY_ARC
            path = arc_to_shortest_path(arc)
            push!(output_paths, path)
        end
    end

    return output_paths
end
