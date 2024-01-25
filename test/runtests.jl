using FlowGenerator
using Test
using HiGHS

@testset "FlowGenerator tests" begin
    include("linked_list_map.jl")
    include("flow_generator.jl")
    include("Solvers/shortest_path_solver.jl")
    include("Solvers/mip_model.jl")
    include("NetworkFlowModel/problem.jl")
    include("NetworkFlowModel/primal_solution.jl")
    include("NetworkFlowModel/network.jl")
end
