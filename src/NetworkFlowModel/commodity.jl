struct Commodity
    index::Int
    source::Vertex
    sink::Vertex
    demand::Float64
    capacity::Float64
    violation_penalty_cost::Float64

    function Commodity(
        index::Int,
        source::Vertex,
        sink::Vertex,
        demand::Float64,
        capacity::Float64,
        violation_penalty_cost::Float64,
    )
        if demand > capacity
            throw(ArgumentError("Demand must be less than or equal to capacity"))
        elseif demand < 0
            throw(ArgumentError("Demand must be non-negative"))
        elseif capacity == Inf
            throw(ArgumentError("Capacity must be finite"))
        end

        return new(index, source, sink, demand, capacity, violation_penalty_cost)
    end
end

get_source(commodity) = commodity.source
get_sink(commodity) = commodity.sink
get_demand(commodity) = commodity.demand
get_capacity(commodity) = commodity.capacity
