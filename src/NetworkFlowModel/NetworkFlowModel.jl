module NetworkFlowModel

import ..DataContainers: IndexedMap, LinkedListMap, add_value!

include("vertex.jl")
include("arc.jl")
include("hyper_tree.jl")
include("path.jl")
include("network.jl")
include("objective_function.jl")
include("constraint.jl")
include("commodity.jl")
include("problem.jl")
include("arc_flow_solution.jl")
include("path_flow_solution.jl")
include("primal_solution.jl")
include("dual_solution.jl")
include("helpers.jl")

export get_vertices,
    get_arcs,
    get_head,
    get_tail_multiplier_list,
    get_network,
    get_constraints,
    get_arc_to_multiplicity,
    topological_sort,
    get_multiplicity
export is_hyper_graph, is_hyper_arc
export new_path, new_network

export filter_arcs

export get_constr_coeff_list
export get_cost, get_coefficient, get_capacity, get_var_type
export get_intermediate_vertices, get_commodities, get_outgoing_arcs
export get_arc_to_flow_map,
    get_obj_val,
    get_arc_flow_solution,
    convert_to_path_flow_solution,
    get_path_flow,
    get_path_to_flow_map
export is_problem_integer, is_integrality_feasible
export push_constraint!, pop_constraint!
export ConstraintType, GEQ, LEQ, EQ
export VarType, INTEGER, CONTINUOUS

export Vertex, Arc, Network, Path
export ObjectiveFunction, Commodity, Constraint, Problem
export PrimalSolution, DualSolution

end
