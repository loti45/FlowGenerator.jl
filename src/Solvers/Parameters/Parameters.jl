module Parameters

import ..AbstractSolver: AbstractSolverParams

Base.@kwdef struct MipSolverParams <: AbstractSolverParams
    mip_optimizer::Any
    is_silent::Bool = false
    primal_decimal_precision::Int = 12
    dual_decimal_precision::Int = 12
    linear_relaxation::Bool = false
end

abstract type AbstractBasisKind end
struct ArcFlowBasis <: AbstractBasisKind end
struct PathFlowBasis <: AbstractBasisKind end

abstract type AbstractPricingKind end
Base.@kwdef struct ShortestPathPricing <: AbstractPricingKind
    pseudo_complementary::Bool = true
end

Base.@kwdef struct ColumnGenerationParams{S} <:
                   AbstractSolverParams where {S<:AbstractSolverParams}
    lp_solver_params::S
    min_rc_to_stop::Float64 = -1e-9
    basis_kind::AbstractBasisKind = PathFlowBasis()
    pricing_kind::AbstractPricingKind = ShortestPathPricing()
    num_zero_flow_iter_delete_column::Int = typemax(Int)
end

Base.@kwdef struct NetworkFlowSolverParams{S,T} <: AbstractSolverParams where {
    S<:AbstractSolverParams,T<:AbstractSolverParams
}
    exact_solver_params::S
    lp_solver_params::T
    right_branch_violation_penalty_cost::Float64 = 1e3
    feas_tol::Float64 = 1e-6
    obj_cutoff::Float64 = Inf
    arc_to_family::Function = arc -> arc.head
    max_num_branching_levels::Int = 10
end

function new_network_flow_solver_params(
    mip_optimizer; obj_cutoff::Number = Inf, basis_kind::AbstractBasisKind = PathFlowBasis()
)
    lp_solver_params = ColumnGenerationParams(;
        lp_solver_params = MipSolverParams(; mip_optimizer, is_silent = true), basis_kind
    )
    exact_solver_params = MipSolverParams(; mip_optimizer)
    return NetworkFlowSolverParams(; exact_solver_params, lp_solver_params, obj_cutoff)
end

get_lp_solver_params(params::NetworkFlowSolverParams) = params.lp_solver_params
get_exact_solver_params(params::NetworkFlowSolverParams) = params.exact_solver_params

export get_exact_solver_params, get_lp_solver_params, new_network_flow_solver_params

export NetworkFlowSolverParams

end
