module MipModel

using JuMP
using ..AbstractSolver, ..DataContainers, ..NetworkFlowModel
using DataStructures

import .DataContainers: IndexedMap, LinkedListMap, add_value!

import ..Parameters: MipSolverParams

const DEFAULT_PRIMAL_DECIMAL_PRECISION = 6

include("commodity_flow_component.jl")
include("mip_model.jl")

"""
    AbstractSolver.solve(
        problem::NetworkFlowModel.Problem, 
        params::MipSolverParams;
        time_limit::Float64 = Inf
    ) -> PrimalSolution

Solve a network flow problem directly as a mixed-integer programming (MIP) model. 
Keyword parameter time_limit is given in seconds.

# Returns
- A `PrimalSolution` object representing the optimal solution.
"""
function AbstractSolver.solve(
    problem::NetworkFlowModel.Problem, params::MipSolverParams; time_limit::Float64 = Inf
)
    println("\n+ Solving problem with $(length(get_arcs(get_network(problem)))) arcs")
    if isempty(get_arcs(problem))
        return PrimalSolution(problem)
    end
    mip_model = MipModel.NetworkFlowMipModel(problem, params)

    for commodity in get_commodities(problem)
        for arc in get_arcs(get_network(problem))
            var_type = if params.linear_relaxation
                CONTINUOUS
            else
                get_var_type(problem, arc)
            end
            MipModel.add_arc_var!(mip_model, commodity, arc; var_type)
        end
    end

    MipModel.optimize!(mip_model; time_limit)
    return MipModel.get_primal_solution(mip_model)
end

export optimize!, get_primal_solution, get_dual_solution, get_paths
end
