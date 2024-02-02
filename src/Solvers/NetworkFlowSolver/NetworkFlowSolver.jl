module NetworkFlowSolver

using JuMP
using ..AbstractSolver, ..ColumnGeneration, ..MipModel, ..NetworkFlowModel, ..Parameters
import .Parameters: NetworkFlowSolverParams

include("reduced_cost_fixing.jl")

"""
    AbstractSolver.solve(
        problem::NetworkFlowModel.Problem,
        params::NetworkFlowSolverParams;
        initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
        initial_columns = MipModel.Column[
            MipModel.Column(problem, path, commodity) for (commodity, path) in initial_paths
        ],
        obj_cutoff::Number = params.obj_cutoff,
        max_num_branching_levels::Int,
    ) -> NetworkFlowModel.PrimalSolution

Solves a network flow model problem by column generation, branching, and reduced-cost variable-fixing.
The function applies unbalanced branching to favor finding good quality primal solutions, up to a specified maximum number
of branching levels.
"""
function AbstractSolver.solve(
    problem::NetworkFlowModel.Problem,
    params::NetworkFlowSolverParams;
    initial_paths::Vector{Tuple{Commodity,Path}} = Tuple{Commodity,Path}[],
    initial_columns = MipModel.Column[
        MipModel.Column(problem, path, commodity) for (commodity, path) in initial_paths
    ],
    obj_cutoff::Number = params.obj_cutoff,
    max_num_branching_levels::Int,
)
    if isempty(get_commodities(problem))
        throw(ArgumentError("Problem with no commodities"))
    end
    if isempty(get_arcs(problem))
        return PrimalSolution(problem)
    end

    # solving relaxation
    full_lp_solution = solve(problem, get_lp_solver_params(params); initial_columns)
    lp_primal_solution = ColumnGeneration.get_primal_solution(full_lp_solution)

    initial_columns = get_rmp_columns(full_lp_solution)

    # removing arcs by reduced cost fixing
    problem = reduced_cost_fixing(problem, full_lp_solution, obj_cutoff)
    println("+ NetworkFlowSolver ($max_num_branching_levels)")
    println("+ Number of arcs after RCVF: $(length(get_arcs(problem)))")

    if isempty(get_arcs(problem))
        return PrimalSolution(problem)
    end

    # solving problem to integer optimality
    integer_optimal_solution = if is_integrality_feasible(problem, lp_primal_solution)
        lp_primal_solution
    elseif max_num_branching_levels <= 0
        solve(problem, get_exact_solver_params(params))
    else
        solve_by_unbalanced_branching(
            problem,
            params,
            initial_columns,
            obj_cutoff,
            max_num_branching_levels,
            lp_primal_solution,
        )
    end

    return integer_optimal_solution
end

function solve_by_unbalanced_branching(
    problem::NetworkFlowModel.Problem,
    params::NetworkFlowSolverParams,
    initial_columns::Vector{MipModel.Column},
    obj_cutoff::Number,
    max_num_branching_levels::Int,
    lp_solution::PrimalSolution,
)
    branching_arc_set = _get_branching_arc_set(problem, params, lp_solution)

    # left branch - removes all arcs in branching_arc_set
    left_branch_problem = get_left_branch_problem(problem, branching_arc_set)
    left_branch_solution = solve(left_branch_problem, get_exact_solver_params(params))
    @show get_obj_val(left_branch_problem, left_branch_solution)
    obj_cutoff = min(
        obj_cutoff, _get_obj_cutoff(problem, get_obj_val(problem, left_branch_solution))
    )

    # right branch
    right_branch_constraint = _get_right_branch_constraint(
        problem, branching_arc_set, params.right_branch_violation_penalty_cost
    )
    push_constraint!(problem, right_branch_constraint)
    right_branch_solution = solve(
        problem,
        params;
        initial_columns,
        obj_cutoff,
        max_num_branching_levels = max_num_branching_levels - 1,
    )
    pop_constraint!(problem)

    return get_best_sol(problem, [left_branch_solution, right_branch_solution])
end

function get_columns(problem::NetworkFlowModel.Problem, primal_solution::PrimalSolution)
    output = Tuple{Commodity,Path}[]
    for commodity in get_commodities(problem)
        arc_flow_solution = get_arc_flow_solution(primal_solution, commodity)
        path_flow_solution = convert_to_path_flow_solution(
            get_network(problem), arc_flow_solution
        )
        for (path, _) in path_flow_solution.path_to_flow_map
            push!(output, (commodity, path))
        end
    end
    return output
end

function get_left_branch_problem(problem::Problem, branching_arcs)
    return NetworkFlowModel.filter_arcs(problem, arc -> !(arc in branching_arcs))
end

function get_best_sol(problem::Problem, solutions)
    solutions = filter(s -> !isnothing(s), solutions)
    best_sol = nothing
    for sol in solutions
        if isnothing(best_sol) || get_obj_val(problem, sol) < get_obj_val(problem, best_sol)
            best_sol = sol
        end
    end
    return best_sol
end

function _get_branching_arc_set(
    problem::NetworkFlowModel.Problem,
    params::NetworkFlowSolverParams,
    solution::PrimalSolution,
)
    family_to_flow = Dict()
    get_family_flow = arc -> get(family_to_flow, params.arc_to_family(arc), 0.0)
    for commodity in get_commodities(problem)
        for (arc, flow) in get_arc_to_flow_map(solution, commodity)
            family_to_flow[params.arc_to_family(arc)] = get_family_flow(arc) + flow
        end
    end

    return Set(arc for arc in get_arcs(problem) if get_family_flow(arc) < params.feas_tol)
end

function _get_right_branch_constraint(
    problem::Problem, branching_arc_set::Set{Arc}, violation_penalty_cost::Float64
)
    index = length(get_constraints(problem)) + 1
    arc_to_coefficient = Dict(arc => 1.0 for arc in branching_arc_set)
    return Constraint(index, arc_to_coefficient, GEQ, 1.0, violation_penalty_cost)
end

function _get_obj_cutoff(problem::NetworkFlowModel.Problem, obj_val::Number)
    if is_problem_integer(problem)
        return obj_val - 1
    else
        return obj_val
    end
end

end
