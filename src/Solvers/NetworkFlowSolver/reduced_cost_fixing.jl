# Remove arcs that are not good candidates to find a solution better than cutoff
function reduced_cost_fixing(
    problem::Problem, linear_solution::ColumnGeneration.Solution, objective_cutoff::Number
)
    return NetworkFlowModel.filter_arcs(
        problem, arc -> get_min_obj_val(linear_solution, arc) <= objective_cutoff
    )
end
