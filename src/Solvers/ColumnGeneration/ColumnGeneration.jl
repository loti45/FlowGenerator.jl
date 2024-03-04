module ColumnGeneration

using JuMP

using ..AbstractSolver,
    ..DataContainers, ..MipModel, ..NetworkFlowModel, ..Parameters, ..ShortestPathSolver

import .DataContainers: IndexedMap, LinkedListMap, add_value!
import .Parameters: ColumnGenerationParams, ArcFlowBasis, PathFlowBasis

include("rmp.jl")
include("extended_dual_solution.jl")
include("pricing_solver.jl")
include("column_generation.jl")

struct Solution
    primal_solution::PrimalSolution
    rmp_columns::Vector{MipModel.Column}
    arc_to_min_obj_val::IndexedMap{Arc,Float64}
end

function AbstractSolver.solve(
    problem::NetworkFlowModel.Problem,
    params::ColumnGenerationParams;
    initial_columns::Vector{MipModel.Column} = MipModel.Column[],
)
    pricing_solver = PricingSolver(problem, params)
    rmp = ColumnGenerationOptimizer(problem, params)
    optimize_column_generation!(problem, params; initial_columns, rmp, pricing_solver)

    return Solution(
        get_primal_solution(rmp),
        get_current_columns(rmp),
        get_arc_to_min_obj_val(problem, pricing_solver.sp_solution),
    )
end

get_primal_solution(sol::Solution) = sol.primal_solution
get_dual_solution(sol::Solution) = sol.dual_solution
get_rmp_columns(sol::Solution) = sol.rmp_columns

function get_min_obj_val(sol::Solution, arc::Arc)
    return sol.arc_to_min_obj_val[arc]
end

export get_primal_solution, get_dual_solution, get_min_obj_val, get_rmp_columns

end
