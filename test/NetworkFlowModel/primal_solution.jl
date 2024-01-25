@testset "Simple arc flow solution" begin
    problem_builder = FlowGenerator.new_problem_builder()

    v1 = FlowGenerator.new_vertex!(problem_builder)
    v2 = FlowGenerator.new_vertex!(problem_builder)
    v3 = FlowGenerator.new_vertex!(problem_builder)
    v4 = FlowGenerator.new_vertex!(problem_builder)

    arc1 = FlowGenerator.new_arc!(problem_builder, v1, v2)
    arc2 = FlowGenerator.new_arc!(problem_builder, v1, v3)
    arc3 = FlowGenerator.new_arc!(problem_builder, v2, v3)
    arc4 = FlowGenerator.new_arc!(problem_builder, v2, v4)
    arc5 = FlowGenerator.new_arc!(problem_builder, v3, v4)

    arc_to_flow_map = Dict([
        arc1 => 10.0, arc2 => 10.0, arc3 => 5.0, arc4 => 5.0, arc5 => 15.0
    ])
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v1) == 0.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v2) == 10.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v3) == 15.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v4) == 20.0

    flow_conversation_balance = FlowGenerator.NetworkFlowModel.get_flow_conservation_balance(
        arc_flow_solution
    )
    @test flow_conversation_balance[v1] == -20.0
    @test flow_conversation_balance[v2] == 0.0
    @test flow_conversation_balance[v3] == 0.0
    @test flow_conversation_balance[v4] == 20.0
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        true

    # make flow conservation infeasible
    arc_to_flow_map[arc1] = 11.0
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        false

    # make flow conservation feasible again
    arc_to_flow_map[arc1] = 10.0
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        true

    # test flow decomposition solution
    problem = FlowGenerator.get_problem(problem_builder)
    network = FlowGenerator.get_network(problem)

    path_flow_solution = FlowGenerator.convert_to_path_flow_solution(
        network, arc_flow_solution
    )
    path1 = FlowGenerator.new_path([arc1, arc4])
    path2 = FlowGenerator.new_path([arc1, arc3, arc5])
    path3 = FlowGenerator.new_path([arc2, arc5])

    @test FlowGenerator.get_path_flow(path_flow_solution, path1) == 5.0
    @test FlowGenerator.get_path_flow(path_flow_solution, path2) == 5.0
    @test FlowGenerator.get_path_flow(path_flow_solution, path3) == 10.0
end

@testset "Generalized arc flow solution" begin
    problem_builder = FlowGenerator.new_problem_builder()

    v1 = FlowGenerator.new_vertex!(problem_builder)
    v2 = FlowGenerator.new_vertex!(problem_builder)
    v3 = FlowGenerator.new_vertex!(problem_builder)
    v4 = FlowGenerator.new_vertex!(problem_builder)

    arc1 = FlowGenerator.new_arc!(problem_builder, (v1, 10.0), v2)
    arc2 = FlowGenerator.new_arc!(problem_builder, (v1, 15.0), v3)
    arc3 = FlowGenerator.new_arc!(problem_builder, (v2, 0.25), v3)
    arc4 = FlowGenerator.new_arc!(problem_builder, (v2, 1.0), v4)
    arc5 = FlowGenerator.new_arc!(problem_builder, (v3, 20.0), v4)

    arc_to_flow_map = Dict([
        arc1 => 10.0, arc2 => 10.0, arc3 => 20.0, arc4 => 5.0, arc5 => 1.5
    ])
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v1) == 0.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v2) == 10.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v3) == 30.0
    @test FlowGenerator.NetworkFlowModel.get_incoming_flow(arc_flow_solution, v4) == 6.5

    flow_conversation_balance = FlowGenerator.NetworkFlowModel.get_flow_conservation_balance(
        arc_flow_solution
    )
    @test flow_conversation_balance[v1] == -250.0
    @test flow_conversation_balance[v2] == 0.0
    @test flow_conversation_balance[v3] == 0.0
    @test flow_conversation_balance[v4] == 6.5
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        true

    # make flow conservation infeasible
    arc_to_flow_map[arc1] = 11.0
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        false

    # make flow conservation feasible again
    arc_to_flow_map[arc1] = 10.0
    arc_flow_solution = FlowGenerator.NetworkFlowModel.ArcFlowSolution(
        arc_to_flow_map, v1, v4
    )
    @test FlowGenerator.NetworkFlowModel.is_flow_conservation_feasible(arc_flow_solution) ==
        true

    # test flow decomposition solution
    problem = FlowGenerator.get_problem(problem_builder)
    network = FlowGenerator.get_network(problem)

    path_flow_solution = FlowGenerator.convert_to_path_flow_solution(
        network, arc_flow_solution
    )
    path1 = FlowGenerator.new_path([arc1, arc4])
    path2 = FlowGenerator.new_path([arc1, arc3, arc5])
    path3 = FlowGenerator.new_path([arc2, arc5])

    @test FlowGenerator.NetworkFlowModel.compute_max_feasible_flow(
        arc_to_flow_map, path1
    ) == 5.0
    @test FlowGenerator.NetworkFlowModel.compute_max_feasible_flow(
        arc_to_flow_map, path2
    ) == 1.0
    @test FlowGenerator.NetworkFlowModel.compute_max_feasible_flow(
        arc_to_flow_map, path3
    ) == 0.5
    @test FlowGenerator.get_path_flow(path_flow_solution, path1) == 5.0
    @test FlowGenerator.get_path_flow(path_flow_solution, path2) == 1.0
    @test FlowGenerator.get_path_flow(path_flow_solution, path3) == 0.5
end
