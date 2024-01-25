module FlowGenerator

include("DataContainers/DataContainers.jl")
using .DataContainers

include("NetworkFlowModel/NetworkFlowModel.jl")
using .NetworkFlowModel

include("Solvers/AbstractSolver.jl")
using .AbstractSolver

include("Solvers/Parameters/Parameters.jl")
using .Parameters

include("Solvers/ShortestPathSolver/ShortestPathSolver.jl")
using .ShortestPathSolver

include("Solvers/MipModel/MipModel.jl")
using .MipModel

include("Solvers/ColumnGeneration/ColumnGeneration.jl")
using .ColumnGeneration

include("Solvers/NetworkFlowSolver/NetworkFlowSolver.jl")
using .NetworkFlowSolver

include("interface.jl")

export new_problem_builder,
    new_vertex!,
    new_arc!,
    new_commodity!,
    new_constraint!,
    set_constraint_coefficient!,
    set_cost!,
    set_capacity!,
    set_var_type!

export get_problem,
    optimize!,
    optimize_by_mip_solver!,
    optimize_linear_relaxation!,
    filter_arcs_by_reduced_cost,
    get_flow,
    get_network,
    get_multiplicity,
    get_arc_to_multiplicity,
    get_cost,
    get_obj_val,
    get_path_to_flow_map,
    get_arcs

export new_network_flow_solver_params

export Arc, Commodity, Vertex

export CONTINUOUS, INTEGER

export Parameters

end
