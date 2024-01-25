@testset "Mip model" begin
    @testset "Generalized hyper-graph flow" begin
        problem_builder = FlowGenerator.new_problem_builder()

        v = [FlowGenerator.new_vertex!(problem_builder) for _ in 1:7]

        arc1 = FlowGenerator.new_arc!(problem_builder, v[1], v[2]; cost = 1.0)
        arc2 = FlowGenerator.new_arc!(problem_builder, v[1], v[3]; cost = 1.0)
        arc3 = FlowGenerator.new_arc!(problem_builder, v[1], v[4]; cost = 3.5)
        arc4 = FlowGenerator.new_arc!(
            problem_builder, Dict(v[2] => 1.0, v[3] => 1.0), v[4]; cost = 1.0
        )
        arc5 = FlowGenerator.new_arc!(problem_builder, v[3], v[5]; cost = 1.0)
        arc6 = FlowGenerator.new_arc!(
            problem_builder, Dict(v[4] => 1.0, v[5] => 2.0), v[6]; cost = 1.0
        )
        arc7 = FlowGenerator.new_arc!(problem_builder, v[6], v[7]; cost = 1.0)

        c1 = FlowGenerator.new_commodity!(problem_builder, v[1], v[7], 10.0, 10.0)

        params = FlowGenerator.Parameters.MipSolverParams(; mip_optimizer = HiGHS.Optimizer)
        solve_and_test_solution =
            (arc_to_flow) -> begin
                problem = FlowGenerator.get_problem(problem_builder)
                solution = FlowGenerator.solve(problem, params)
                for (arc, flow) in arc_to_flow
                    @test FlowGenerator.get_flow(solution, c1, arc) == flow
                    @test FlowGenerator.get_flow(solution, arc) == flow
                end
            end

        solve_and_test_solution(
            Dict(
                arc1 => 10.0,
                arc2 => 30.0,
                arc3 => 0.0,
                arc4 => 10.0,
                arc5 => 20.0,
                arc6 => 10.0,
                arc7 => 10.0,
            ),
        )

        FlowGenerator.set_capacity!(problem_builder, arc1, 5.5)
        solve_and_test_solution(
            Dict(
                arc1 => 5.5,
                arc2 => 25.5,
                arc3 => 4.5,
                arc4 => 5.5,
                arc5 => 20.0,
                arc6 => 10.0,
                arc7 => 10.0,
            ),
        )

        FlowGenerator.set_var_type!(problem_builder, arc1, FlowGenerator.INTEGER)
        solve_and_test_solution(
            Dict(
                arc1 => 5.0,
                arc2 => 25.0,
                arc3 => 5.0,
                arc4 => 5.0,
                arc5 => 20.0,
                arc6 => 10.0,
                arc7 => 10.0,
            ),
        )
    end
end
