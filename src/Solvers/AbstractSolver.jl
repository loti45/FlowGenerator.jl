module AbstractSolver

using ..NetworkFlowModel

abstract type AbstractSolverParams end

# Main solve function that should be implemented by each solver
function solve(problem::NetworkFlowModel.Problem, params::AbstractSolverParams; aux_data)
    throw(MethodError(solve, (problem, params, aux_data)))
end

export solve
export AbstractSolverParams

end
