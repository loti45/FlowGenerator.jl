@testset "push and pop constraints" begin
    problem_builder = new_problem_builder()

    v1 = new_vertex!(problem_builder)
    v2 = new_vertex!(problem_builder)
    v3 = new_vertex!(problem_builder)

    arc1 = new_arc!(problem_builder, v1, v2)
    arc2 = new_arc!(problem_builder, v1, v3)

    problem = get_problem(problem_builder)

    @test length(FlowGenerator.get_constraints(problem)) == 0

    ctr1 = FlowGenerator.Constraint(1, Dict(arc1 => 1.0), FlowGenerator.GEQ, 1.0, 0.0)
    ctr2 = FlowGenerator.Constraint(
        2, Dict(arc1 => 1.0, arc2 => 3.0), FlowGenerator.EQ, 1.0, 0.0
    )
    FlowGenerator.push_constraint!(problem, ctr1)
    @test length(FlowGenerator.get_constraints(problem)) == 1
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc1)) == [(1, 1.0)]
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc2)) == []
    FlowGenerator.push_constraint!(problem, ctr2)
    @test length(FlowGenerator.get_constraints(problem)) == 2
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc1)) ==
        [(2, 1.0), (1, 1.0)]
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc2)) == [(2, 3.0)]
    FlowGenerator.pop_constraint!(problem)
    @test length(FlowGenerator.get_constraints(problem)) == 1
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc1)) == [(1, 1.0)]
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc2)) == []
    FlowGenerator.pop_constraint!(problem)
    @test length(FlowGenerator.get_constraints(problem)) == 0
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc1)) == []
    @test collect(FlowGenerator.get_constr_coeff_list(problem, arc2)) == []
end
