mutable struct ColumnGenerationOptimizer
    rmp::MipModel.NetworkFlowMipModel # restricted master problem
    problem::NetworkFlowModel.Problem
    params::ColumnGenerationParams
    path_to_nonbasic_iterations_count::Dict{NetworkFlowModel.Path,Int}
    arc_to_nonbasic_iterations_count::Dict{NetworkFlowModel.Arc,Int}
end

NetworkFlowModel.get_network(cg::ColumnGenerationOptimizer) = get_network(cg.problem)
NetworkFlowModel.get_cost(cg::ColumnGenerationOptimizer, obj) = get_cost(cg.problem, obj)

function NetworkFlowModel.get_commodities(cg::ColumnGenerationOptimizer)
    return NetworkFlowModel.get_commodities(cg.problem)
end

function ColumnGenerationOptimizer(problem, params)
    rmp = MipModel.NetworkFlowMipModel(problem, params.lp_solver_params)
    return ColumnGenerationOptimizer(rmp, problem, params, Dict(), Dict())
end

function optimize!(cg_optimizer::ColumnGenerationOptimizer)
    return MipModel.optimize!(cg_optimizer.rmp)
end

function get_current_columns(rmp::ColumnGenerationOptimizer)
    output = MipModel.Column[]
    for commodity in get_commodities(rmp)
        for column in get_columns(rmp.rmp, commodity)
            push!(output, column)
        end
    end
    return output
end

"""
    add_column!(cg::ColumnGenerationOptimizer, column::Column)

Add a column to the the underlying RMP if it does not already exist.
Return true if the column was added, false otherwise.
"""
function add_column!(cg::ColumnGenerationOptimizer, column::MipModel.Column)
    return MipModel.add_column!(cg.rmp, column)
end

function filter_rmp!(cg::ColumnGenerationOptimizer)
    # TODO : filter columns that become non-attractive:
    # - Columns with positive reduced cost
    # - Columns keeping zero primal value for many iterations
end

function get_nonbasic_iteration_count(cg::ColumnGenerationOptimizer, path::Path)
    return get(cg.path_to_nonbasic_iterations_count, path, 0)
end

function get_nonbasic_iteration_count(cg::ColumnGenerationOptimizer, arc::Arc)
    return get(cg.arc_to_nonbasic_iterations_count, arc, 0)
end

function get_primal_solution(cg::ColumnGenerationOptimizer)
    return MipModel.get_primal_solution(cg.rmp)
end

function get_dual_solution(cg::ColumnGenerationOptimizer)
    return MipModel.get_dual_solution(cg.rmp)
end
