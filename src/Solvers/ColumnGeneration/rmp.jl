mutable struct ColumnGenerationOptimizer
    rmp::MipModel.NetworkFlowMipModel # restricted master problem
    problem::NetworkFlowModel.Problem
    params::ColumnGenerationParams
    column_to_zero_flow_iter_count::Dict{MipModel.Column,Int}
end

NetworkFlowModel.get_network(cg::ColumnGenerationOptimizer) = get_network(cg.problem)
NetworkFlowModel.get_cost(cg::ColumnGenerationOptimizer, obj) = get_cost(cg.problem, obj)

function NetworkFlowModel.get_commodities(cg::ColumnGenerationOptimizer)
    return NetworkFlowModel.get_commodities(cg.problem)
end

function ColumnGenerationOptimizer(problem, params)
    rmp = MipModel.NetworkFlowMipModel(problem, params.lp_solver_params)
    return ColumnGenerationOptimizer(rmp, problem, params, Dict())
end

function optimize!(cg::ColumnGenerationOptimizer)
    MipModel.optimize!(cg.rmp)
    for commodity in get_commodities(cg)
        for (column, val) in MipModel.get_column_to_primal_value_map(cg.rmp, commodity)
            if iszero(val)
                cg.column_to_zero_flow_iter_count[column] =
                    get(cg.column_to_zero_flow_iter_count, column, 0) + 1
            else
                cg.column_to_zero_flow_iter_count[column] = 0
            end
        end
    end
    return nothing
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
    for (column, it_count) in cg.column_to_zero_flow_iter_count
        if it_count > cg.params.num_zero_flow_iter_delete_column
            MipModel.delete_column_var!(cg.rmp, column)
            delete!(cg.column_to_zero_flow_iter_count, column)
        end
    end
    return nothing
end

function get_primal_solution(cg::ColumnGenerationOptimizer)
    return MipModel.get_primal_solution(cg.rmp)
end

function get_dual_solution(cg::ColumnGenerationOptimizer)
    return MipModel.get_dual_solution(cg.rmp)
end
