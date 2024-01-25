abstract type AbstractColumn end
struct ArcColumn <: AbstractColumn
    arc::Arc
    commodity::Commodity
end

struct PathColumn <: AbstractColumn
    path::NetworkFlowModel.Path
    commodity::Commodity
end

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
    output = AbstractColumn[]
    for commodity in get_commodities(rmp)
        for path in get_paths(rmp.rmp, commodity)
            push!(output, PathColumn(path, commodity))
        end
        for arc in get_arcs(rmp.rmp, commodity)
            push!(output, ArcColumn(arc, commodity))
        end
    end
    return output
end

NetworkFlowModel.get_arcs(column::PathColumn) = keys(get_arc_to_multiplicity(column.path))
NetworkFlowModel.get_arcs(column::ArcColumn) = (column.arc,)

function add_column!(cg::ColumnGenerationOptimizer, column::AbstractColumn)
    commodity = column.commodity
    output = false # true if the column was added
    if cg.params.basis_kind isa ArcFlowBasis || column isa ArcColumn
        for arc in get_arcs(column)
            if MipModel.add_arc_var!(cg.rmp, commodity, arc)
                output = true
            end
        end
    elseif cg.params.basis_kind isa PathFlowBasis
        if MipModel.add_path_var!(cg.rmp, commodity, column.path)
            output = true
        end
    else
        throw(ArgumentError("Unsupported solver kind"))
    end
    return output
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
