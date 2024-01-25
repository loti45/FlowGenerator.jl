@testset "Network" begin
    problem_builder = FlowGenerator.new_problem_builder()

    v0 = FlowGenerator.new_vertex!(problem_builder)
    v1 = FlowGenerator.new_vertex!(problem_builder)
    v2 = FlowGenerator.new_vertex!(problem_builder)
    v3 = FlowGenerator.new_vertex!(problem_builder)
    v4 = FlowGenerator.new_vertex!(problem_builder)

    arc0 = FlowGenerator.new_arc!(problem_builder, (v0, 1.0), v1; cost = 1.0)
    arc1 = FlowGenerator.new_arc!(problem_builder, (v1, 0.5), v2; cost = 2.0)
    arc2 = FlowGenerator.new_arc!(problem_builder, (v2, 0.5), v3; cost = 3.0)
    arc3 = FlowGenerator.new_arc!(problem_builder, (v3, 5.0), v4; cost = 4.0)

    @testset "Arc" begin
        problem = FlowGenerator.get_problem(problem_builder)
        @test FlowGenerator.get_cost(problem, arc0) == 1.0
        @test FlowGenerator.get_cost(problem, arc1) == 2.0
        @test FlowGenerator.get_cost(problem, arc2) == 3.0
        @test FlowGenerator.get_cost(problem, arc3) == 4.0
    end

    @testset "Path" begin
        problem = FlowGenerator.get_problem(problem_builder)
        path = FlowGenerator.new_path([arc0, arc1, arc2, arc3])
        arc_to_multiplicity = FlowGenerator.get_arc_to_multiplicity(path)
        @test arc_to_multiplicity[arc0] == 1.25
        @test arc_to_multiplicity[arc1] == 2.5
        @test arc_to_multiplicity[arc2] == 5.0
        @test arc_to_multiplicity[arc3] == 1

        @test FlowGenerator.get_cost(problem, path) == 25.25

        path2 = FlowGenerator.new_path([arc0, arc1, arc2, arc3])
        path3 = FlowGenerator.new_path([arc0, arc1, arc2])

        @test path == path2
        @test path != path3
    end

    @testset "Network" begin
        network = FlowGenerator.new_network([v0, v1, v2, v3, v4], [arc0, arc1, arc3])
        @test arc0 in network
        @test arc1 in network
        @test !(arc2 in network)
        @test arc3 in network
        @test collect(FlowGenerator.get_outgoing_arcs(network, v0)) == [arc0]
        @test collect(FlowGenerator.get_outgoing_arcs(network, v1)) == [arc1]
        @test collect(FlowGenerator.get_outgoing_arcs(network, v2)) == []
        @test collect(FlowGenerator.get_outgoing_arcs(network, v3)) == [arc3]

        path1 = FlowGenerator.new_path([arc0, arc1])
        path2 = FlowGenerator.new_path([arc0, arc1, arc2])

        @test path1 in network
        @test !(path2 in network)

        filtered_network = FlowGenerator.filter_arcs(network, arc -> arc != arc1)
        @test FlowGenerator.get_arcs(filtered_network) == [arc0, arc3]
    end

    @testset "Topological sort" begin
        problem_builder = FlowGenerator.new_problem_builder()

        v1 = FlowGenerator.new_vertex!(problem_builder)
        v2 = FlowGenerator.new_vertex!(problem_builder)
        v3 = FlowGenerator.new_vertex!(problem_builder)
        v4 = FlowGenerator.new_vertex!(problem_builder)
        v5 = FlowGenerator.new_vertex!(problem_builder)

        c1 = FlowGenerator.new_commodity!(problem_builder, v1, v4, 1.0, 1.0)
        arc1 = FlowGenerator.new_arc!(problem_builder, v3, v1)
        arc2 = FlowGenerator.new_arc!(problem_builder, v1, v2)
        arc3 = FlowGenerator.new_arc!(problem_builder, v2, v5)
        arc4 = FlowGenerator.new_arc!(problem_builder, v5, v4)

        problem = FlowGenerator.get_problem(problem_builder)
        network = FlowGenerator.get_network(problem)

        @test FlowGenerator.topological_sort(network, v3) == [v3, v1, v2, v5, v4]
        @test FlowGenerator.topological_sort(network, v5) == [v5, v4]
        @test FlowGenerator.topological_sort(network, [v1, v5]) == [v1, v2, v5, v4]

        # introducing cycle
        arc4 = FlowGenerator.new_arc!(problem_builder, v2, v3)

        problem = FlowGenerator.get_problem(problem_builder)
        network = FlowGenerator.get_network(problem)
        @test_throws ErrorException FlowGenerator.topological_sort(network, v3)
        @test FlowGenerator.topological_sort(network, v5) == [v5, v4]
        @test_throws ErrorException FlowGenerator.topological_sort(network, [v1, v5])
    end
end
