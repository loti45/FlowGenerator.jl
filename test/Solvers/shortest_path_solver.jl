@testset "ShortestPathSolver tests" begin
    @testset "Shortest path solution" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, v1, v2)
        arc2 = new_arc!(problem_builder, v1, v3)
        arc3 = new_arc!(problem_builder, v2, v3)
        arc4 = new_arc!(problem_builder, v2, v4)
        arc5 = new_arc!(problem_builder, v3, v4)

        arc_to_cost = Dict()
        arc_to_cost[arc1] = 10.0
        arc_to_cost[arc2] = 10.0
        arc_to_cost[arc3] = 10.0
        arc_to_cost[arc4] = 1.0
        arc_to_cost[arc5] = 1.0

        expected_sol = [
            (arc1, 11.0, [arc1, arc4]),
            (arc2, 11.0, [arc2, arc5]),
            (arc3, 21.0, [arc1, arc3, arc5]),
            (arc4, 11.0, [arc1, arc4]),
            (arc5, 11.0, [arc2, arc5]),
        ]

        problem = get_problem(problem_builder)
        shortest_path_solution = FlowGenerator.generate_shortest_path(
            get_network(problem), v1, v4, arc_to_cost
        )

        for (arc, cost, opt_arc_seq) in expected_sol
            path = FlowGenerator.new_path(opt_arc_seq)
            @test FlowGenerator.get_min_unit_flow_path(shortest_path_solution, arc) == path
            @test FlowGenerator.get_min_unit_flow_cost(shortest_path_solution, arc) == cost
            @test get_cost(shortest_path_solution, path) == cost
        end
    end

    @testset "Generalized shortest path solution" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, (v1, 0.5), v2)
        arc2 = new_arc!(problem_builder, (v2, 5.0), v3)
        arc3 = new_arc!(problem_builder, (v2, 0.25), v4)
        arc4 = new_arc!(problem_builder, (v3, 1.0), v4)

        arc_to_cost = Dict()
        arc_to_cost[arc1] = 1.25
        arc_to_cost[arc2] = 1.0
        arc_to_cost[arc3] = 1.0
        arc_to_cost[arc4] = 1.0

        problem = get_problem(problem_builder)
        shortest_path_solution = FlowGenerator.generate_shortest_path(
            get_network(problem), v1, v4, arc_to_cost
        )

        @test shortest_path_solution.forward_vertex_to_label[v1].value == 0.0
        @test shortest_path_solution.forward_vertex_to_label[v2].value == 1.25
        @test shortest_path_solution.forward_vertex_to_label[v3].value == 7.25
        @test shortest_path_solution.forward_vertex_to_label[v4].value == 1.3125

        @test shortest_path_solution.backward_vertex_to_label[v4].value == 0.0
        @test shortest_path_solution.backward_vertex_to_label[v3].value == 1.0
        @test shortest_path_solution.backward_vertex_to_label[v2].value == 0.4
        @test shortest_path_solution.backward_vertex_to_label[v1].value == 3.3

        expected_sol = [
            (arc1, 1.65, [arc1, arc2, arc4]),
            (arc2, 8.25, [arc1, arc2, arc4]),
            (arc3, 1.3125, [arc1, arc3]),
            (arc4, 8.25, [arc1, arc2, arc4]),
        ]

        for (arc, cost, opt_arc_seq) in expected_sol
            path = FlowGenerator.new_path(opt_arc_seq)
            @test FlowGenerator.get_min_unit_flow_path(shortest_path_solution, arc) == path
            @test FlowGenerator.get_min_unit_flow_cost(shortest_path_solution, arc) == cost
        end
    end

    @testset "Min cost unit flow" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)
        v5 = new_vertex!(problem_builder)
        v6 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, (v1, 0.35), v2)
        arc2 = new_arc!(problem_builder, (v2, 5.00), v3)
        arc3 = new_arc!(problem_builder, (v2, 0.25), v4)
        arc4 = new_arc!(problem_builder, (v3, 1.00), v4)
        arc5 = new_arc!(problem_builder, (v4, 20.0), v5)
        arc6 = new_arc!(problem_builder, (v5, 0.50), v6)

        arc_to_cost = Dict()
        arc_to_cost[arc1] = 1.25
        arc_to_cost[arc2] = 2.0
        arc_to_cost[arc3] = 3.5
        arc_to_cost[arc4] = -1.5
        arc_to_cost[arc5] = 15.0
        arc_to_cost[arc6] = -1.0

        problem = get_problem(problem_builder)
        shortest_path_solution = FlowGenerator.generate_shortest_path(
            get_network(problem), v1, v6, arc_to_cost
        )

        arcs = [arc1, arc2, arc3, arc4, arc5, arc6]
        for arc in arcs
            path = FlowGenerator.get_min_unit_flow_path(shortest_path_solution, arc)
            arc_multiplicity = get_arc_to_multiplicity(path)[arc]
            path_cost = get_cost(shortest_path_solution, path)
            min_cost_unit_flow = FlowGenerator.get_min_unit_flow_cost(
                shortest_path_solution, arc
            )
            @test path_cost == min_cost_unit_flow * arc_multiplicity
        end
    end

    @testset "Hyper-graph shortest path" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)
        v5 = new_vertex!(problem_builder)
        v6 = new_vertex!(problem_builder)
        v7 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, v1, v2;)
        arc2 = new_arc!(problem_builder, v1, v3;)
        arc3 = new_arc!(problem_builder, v1, v4;)
        arc4 = new_arc!(problem_builder, Dict(v2 => 1.0, v3 => 1.0), v4)
        arc5 = new_arc!(problem_builder, v3, v5)
        arc6 = new_arc!(problem_builder, Dict(v4 => 1.0, v5 => 1.0), v6)
        arc7 = new_arc!(problem_builder, v6, v7)

        arc_to_cost = Dict()
        arc_to_cost[arc1] = 1.5
        arc_to_cost[arc2] = 0.7
        arc_to_cost[arc3] = 1.0
        arc_to_cost[arc4] = 1.0
        arc_to_cost[arc5] = 1.0
        arc_to_cost[arc6] = 1.0
        arc_to_cost[arc7] = 1.0

        problem = get_problem(problem_builder)
        shortest_path_solution = FlowGenerator.generate_shortest_path(
            get_network(problem), v1, v7, arc_to_cost
        )

        shortest_hyper_tree = FlowGenerator.ShortestPathSolver.get_optimal_path(
            shortest_path_solution, v7
        )

        @show shortest_hyper_tree
        @test get_multiplicity(shortest_hyper_tree, arc1) == 0.0
        @test get_multiplicity(shortest_hyper_tree, arc2) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc3) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc4) == 0.0
        @test get_multiplicity(shortest_hyper_tree, arc5) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc6) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc7) == 1.0

        arc_list = [arc1, arc2, arc3, arc4, arc5, arc6, arc7]
        for arc in arc_list
            @test_throws ArgumentError FlowGenerator.get_min_unit_flow_cost(
                shortest_path_solution, arc1
            )
            @test_throws ArgumentError FlowGenerator.get_min_unit_flow_path(
                shortest_path_solution, arc1
            )
        end
    end

    @testset "Generalized hyper-graph shortest path" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)
        v5 = new_vertex!(problem_builder)
        v6 = new_vertex!(problem_builder)
        v7 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, v1, v2)
        arc2 = new_arc!(problem_builder, v1, v3)
        arc3 = new_arc!(problem_builder, v1, v4)
        arc4 = new_arc!(problem_builder, Dict(v2 => 1.0, v3 => 1.0), v4)
        arc5 = new_arc!(problem_builder, v3, v5)
        arc6 = new_arc!(problem_builder, Dict(v4 => 1.0, v5 => 2.0), v6)
        arc7 = new_arc!(problem_builder, v6, v7)

        arc_to_cost = Dict()
        arc_to_cost[arc1] = 1.0
        arc_to_cost[arc2] = 1.0
        arc_to_cost[arc3] = 3.5
        arc_to_cost[arc4] = 1.0
        arc_to_cost[arc5] = 1.0
        arc_to_cost[arc6] = 1.0
        arc_to_cost[arc7] = 1.0

        problem = get_problem(problem_builder)
        shortest_path_solution = FlowGenerator.generate_shortest_path(
            get_network(problem), v1, v7, arc_to_cost
        )

        shortest_hyper_tree = FlowGenerator.ShortestPathSolver.get_optimal_path(
            shortest_path_solution, v7
        )

        #@show shortest_hyper_tree
        @test get_multiplicity(shortest_hyper_tree, arc1) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc2) == 3.0
        @test get_multiplicity(shortest_hyper_tree, arc3) == 0.0
        @test get_multiplicity(shortest_hyper_tree, arc4) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc5) == 2.0
        @test get_multiplicity(shortest_hyper_tree, arc6) == 1.0
        @test get_multiplicity(shortest_hyper_tree, arc7) == 1.0

        arc_list = [arc1, arc2, arc3, arc4, arc5, arc6, arc7]
        for arc in arc_list
            @test_throws ArgumentError FlowGenerator.get_min_unit_flow_cost(
                shortest_path_solution, arc1
            )
            @test_throws ArgumentError FlowGenerator.get_min_unit_flow_path(
                shortest_path_solution, arc1
            )
        end
    end
end
