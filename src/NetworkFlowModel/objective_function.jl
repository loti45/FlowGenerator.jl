struct ObjectiveFunction
    arc_to_cost::IndexedMap{Arc,Float64}

    function ObjectiveFunction(arcs::Vector{Arc}, arc_to_cost::Function)
        return new(IndexedMap{Arc,Float64}(arcs, arc_to_cost; default = 0.0))
    end
end

get_cost(obj_f::ObjectiveFunction, arc::Arc) = obj_f.arc_to_cost[arc]
function get_cost(obj_f::ObjectiveFunction, path::Path)
    return sum(
        get_cost(obj_f, arc) * mult for (arc, mult) in get_arc_to_multiplicity(path);
        init = 0,
    )
end

is_objective_integer(obj_f::ObjectiveFunction) = all(isinteger, values(obj_f.arc_to_cost))
