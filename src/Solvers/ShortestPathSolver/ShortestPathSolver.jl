module ShortestPathSolver

using ..NetworkFlowModel
import ..DataContainers: IndexedMap, LinkedListMap, add_value!, reset!

const DUMMY_VERTEX = Vertex(-1)
const DUMMY_VERTEX_MULT =
    const DUMMY_ARC = NetworkFlowModel.new_arc(-1, (DUMMY_VERTEX, 0.0), Vertex(-2))

include("shortest_path_solution.jl")
include("shortest_path_solver.jl")

export generate_shortest_path

export get_min_unit_flow_path, get_min_unit_flow_cost

end
