function optimize_column_generation!(
    problem::NetworkFlowModel.Problem,
    params::ColumnGenerationParams;
    initial_columns::Vector{AbstractColumn},
    rmp = ColumnGenerationOptimizer(problem, params),
    pricing_solver = PricingSolver(problem, params),
)
    return optimize_column_generation!(rmp, pricing_solver, initial_columns)
end

function optimize_column_generation!(rmp, pricing_solver, initial_columns)
    for column in initial_columns
        add_column!(rmp, column)
    end

    num_iterations = 0
    while true
        num_iterations += 1
        optimize!(rmp)

        primal_solution = get_primal_solution(rmp)
        dual_solution = get_dual_solution(rmp)

        priced_columns = pricing!(pricing_solver, primal_solution, dual_solution)

        if isempty(priced_columns)
            break
        end

        successful_adds = 0
        for column in priced_columns
            if add_column!(rmp, column)
                successful_adds += 1
            end
        end

        if successful_adds == 0
            break
        end

        filter_rmp!(rmp)
    end
    @show num_iterations
    return get_primal_solution(rmp)
end
