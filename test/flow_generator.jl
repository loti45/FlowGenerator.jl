@testset "Test solution" begin
    problem_builder = new_problem_builder()

    v1 = new_vertex!(problem_builder)
    v2 = new_vertex!(problem_builder)
    v3 = new_vertex!(problem_builder)
    v4 = new_vertex!(problem_builder)

    arc1 = new_arc!(problem_builder, v1, v2; cost = 1.0)
    arc2 = new_arc!(problem_builder, v1, v3; cost = 1.0)
    arc3 = new_arc!(problem_builder, v2, v3; cost = 1.0)
    arc4 = new_arc!(problem_builder, v2, v4; cost = 1.0)
    arc5 = new_arc!(problem_builder, v3, v4; cost = 20.0)

    c1 = new_commodity!(problem_builder, v1, v4, 5.0, 5.0)

    @testset "Single-commodity simple flow" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 5.0
        @test get_flow(solution, c1, arc2) == 0.0
        @test get_flow(solution, c1, arc3) == 0.0
        @test get_flow(solution, c1, arc4) == 5.0
        @test get_flow(solution, c1, arc5) == 0.0
    end

    c2 = new_commodity!(problem_builder, v2, v4, 8.0, 8.0)

    @testset "Multi-commodity simple flow" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 5.0
        @test get_flow(solution, c1, arc2) == 0.0
        @test get_flow(solution, c1, arc3) == 0.0
        @test get_flow(solution, c1, arc4) == 5.0
        @test get_flow(solution, c1, arc5) == 0.0
        @test get_flow(solution, c2, arc1) == 0.0
        @test get_flow(solution, c2, arc2) == 0.0
        @test get_flow(solution, c2, arc3) == 0.0
        @test get_flow(solution, c2, arc4) == 8.0
        @test get_flow(solution, c2, arc5) == 0.0
    end

    set_capacity!(problem_builder, arc4, 9.5)

    @testset "Multi-commodity capacity flow" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 1.5
        @test get_flow(solution, c1, arc2) == 3.5
        @test get_flow(solution, c1, arc3) == 0.0
        @test get_flow(solution, c1, arc4) == 1.5
        @test get_flow(solution, c1, arc5) == 3.5
        @test get_flow(solution, c2, arc1) == 0.0
        @test get_flow(solution, c2, arc2) == 0.0
        @test get_flow(solution, c2, arc3) == 0.0
        @test get_flow(solution, c2, arc4) == 8.0
        @test get_flow(solution, c2, arc5) == 0.0
    end

    side_constraint = new_constraint!(problem_builder; lb = 6.0)
    set_constraint_coefficient!(problem_builder, side_constraint, arc1, 1.0)
    set_constraint_coefficient!(problem_builder, side_constraint, arc3, 1.0)

    @testset "Multi-commodity constrained flow" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, arc1) == 3.75
        @test get_flow(solution, arc2) == 1.25
        @test get_flow(solution, arc3) == 2.25
        @test get_flow(solution, arc4) == 9.5
        @test get_flow(solution, arc5) == 3.5
    end

    set_var_type!(problem_builder, arc4, INTEGER)

    @testset "Integer var" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, arc1) == 3.5
        @test get_flow(solution, arc2) == 1.5
        @test get_flow(solution, arc3) == 2.5
        @test get_flow(solution, arc4) == 9.0
        @test get_flow(solution, arc5) == 4.0
    end
end

@testset "Generalized flow" begin
    problem_builder = new_problem_builder()

    v0 = new_vertex!(problem_builder)
    v1 = new_vertex!(problem_builder)
    v2 = new_vertex!(problem_builder)
    v3 = new_vertex!(problem_builder)
    v4 = new_vertex!(problem_builder)

    arc0 = new_arc!(problem_builder, (v0, 1000.0), v1; cost = 1.0) # source multiplier is irrelevant
    arc1 = new_arc!(problem_builder, (v1, 0.5), v2; cost = 1.0)
    arc2 = new_arc!(problem_builder, (v2, 0.5), v3; cost = 1.0)
    arc3 = new_arc!(problem_builder, (v3, 5.0), v4; cost = 1.0)

    c1 = new_commodity!(problem_builder, v0, v4, 10.0, 10.0)

    @testset "Single-commodity simple flow" begin
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc0) == 12.5
        @test get_flow(solution, c1, arc1) == 25.0
        @test get_flow(solution, c1, arc2) == 50.0
        @test get_flow(solution, c1, arc3) == 10.0
    end

    c2 = new_commodity!(problem_builder, v0, v4, 0.0, 100.0)
    side_constraint = new_constraint!(problem_builder; lb = 30.0, ub = 30.0)
    set_constraint_coefficient!(problem_builder, side_constraint, arc1, 1.0)

    @testset "Single-commodity simple flow" begin
        problem = get_problem(problem_builder)

        params = new_network_flow_solver_params(
            HiGHS.Optimizer; basis_kind = Parameters.PathFlowBasis()
        )
        solution = optimize!(problem, params)
        @test get_flow(solution, c1, arc0) == 12.5
        @test get_flow(solution, c1, arc1) == 25.0
        @test get_flow(solution, c1, arc2) == 50.0
        @test get_flow(solution, c1, arc3) == 10.0
        @test get_flow(solution, c2, arc0) == 2.5
        @test get_flow(solution, c2, arc1) == 5.0
        @test get_flow(solution, c2, arc2) == 10.0
        @test get_flow(solution, c2, arc3) == 2.0

        params = Parameters.new_network_flow_solver_params(
            HiGHS.Optimizer; basis_kind = Parameters.ArcFlowBasis()
        )
        solution = optimize!(problem, params)
        @test get_flow(solution, c1, arc0) == 12.5
        @test get_flow(solution, c1, arc1) == 25.0
        @test get_flow(solution, c1, arc2) == 50.0
        @test get_flow(solution, c1, arc3) == 10.0
        @test get_flow(solution, c2, arc0) == 2.5
        @test get_flow(solution, c2, arc1) == 5.0
        @test get_flow(solution, c2, arc2) == 10.0
        @test get_flow(solution, c2, arc3) == 2.0
    end

    @testset "Generalized hyper-graph flow" begin
        problem_builder = new_problem_builder()

        v1 = new_vertex!(problem_builder)
        v2 = new_vertex!(problem_builder)
        v3 = new_vertex!(problem_builder)
        v4 = new_vertex!(problem_builder)
        v5 = new_vertex!(problem_builder)
        v6 = new_vertex!(problem_builder)
        v7 = new_vertex!(problem_builder)

        arc1 = new_arc!(problem_builder, v1, v2; cost = 1.0)
        arc2 = new_arc!(problem_builder, v1, v3; cost = 1.0)
        arc3 = new_arc!(problem_builder, v1, v4; cost = 3.5)
        arc4 = new_arc!(problem_builder, Dict(v2 => 1.0, v3 => 1.0), v4; cost = 1.0)
        arc5 = new_arc!(problem_builder, v3, v5; cost = 1.0)
        arc6 = new_arc!(problem_builder, Dict(v4 => 1.0, v5 => 2.0), v6; cost = 1.0)
        arc7 = new_arc!(problem_builder, v6, v7; cost = 1.0)

        c1 = new_commodity!(problem_builder, v1, v7, 10.0, 10.0)

        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 10.0
        @test get_flow(solution, c1, arc2) == 30.0
        @test get_flow(solution, c1, arc3) == 0.0
        @test get_flow(solution, c1, arc4) == 10.0
        @test get_flow(solution, c1, arc5) == 20.0
        @test get_flow(solution, c1, arc6) == 10.0
        @test get_flow(solution, c1, arc7) == 10.0

        set_capacity!(problem_builder, arc1, 5.5)
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 5.5
        @test get_flow(solution, c1, arc2) == 25.5
        @test get_flow(solution, c1, arc3) == 4.5
        @test get_flow(solution, c1, arc4) == 5.5
        @test get_flow(solution, c1, arc5) == 20.0
        @test get_flow(solution, c1, arc6) == 10.0
        @test get_flow(solution, c1, arc7) == 10.0

        set_var_type!(problem_builder, arc1, INTEGER)
        problem = get_problem(problem_builder)
        solution = optimize!(problem, HiGHS.Optimizer)
        @test get_flow(solution, c1, arc1) == 5.0
        @test get_flow(solution, c1, arc2) == 25.0
        @test get_flow(solution, c1, arc3) == 5.0
        @test get_flow(solution, c1, arc4) == 5.0
        @test get_flow(solution, c1, arc5) == 20.0
        @test get_flow(solution, c1, arc6) == 10.0
        @test get_flow(solution, c1, arc7) == 10.0
    end
end
