# Bin Packing Problem
In the (one-dimensional) bin packing problem (BPP), we are given an unlimited number of bins with identical capacity $W$, and a set $I$ of items. Each item $i \in I$ is associated with a weight $w_i$. The objective of the problem is to pack all items into the minimum number of bins, while respecting the weight capacity of bins.

Here, we consider the classical arc-flow model for the BPP. For details on the model, we refer to the first paper that addressed it in practice:

Valério de Carvalho, J. M. Exact solution of bin‐packing problems using column generation and branch‐and‐bound. _Annals of Operations Research._ 86(0), 629-659 (1999).

The model has a vertex for each possible partial weight (which we call position) in a bin. There are two types of arcs, item arcs and loss arcs.
- Item arcs represent the placement of an arc in a position of an arbitrary bin. In particular, an item $i$ has arcs like $(u, u + w_i)$, where $u \in \{0,\ldots,W\}$ is a vertex representing a position in a bin.
- Loss arcs represent unused space that accumulate at the end of a bin.

Each complete path in this model represents a feasible packing of items in a single bin. The objective of minimizing the number of used bins is translated to minimizing the total flow over the network. This objective can be modelled in multiple ways. Here we choose to model it by setting a uniform cost of $1$ to all arcs leaving the source. This effectively minimizes the number of bins since each unit of flow leaving the source represent the use of a bin.

The size of the graph depends on the sets of feasible positions for each item. There are many studies focusing on generating smaller sets of positions without losing optimality. For simplicity, we consider the seminal approach by Valério de Carvalho, which is based on the principle that items can be assumed to be left-aligned inside of a bin.

The following illustrates how to use FlowGenerator to construct and solve the classical arc-flow model for the BPP.
```julia
using FlowGenerator
using HiGHS

function solve_bin_packing(capacity::Int, weights::Vector{Int})
    num_items = length(weights)

    # builder for the network flow problem
    builder = new_problem_builder()

    # mapping of positions in a bin to vertices
    position_to_vertex = Dict{Int,Vertex}()
    position_to_vertex[0] = new_vertex!(builder)

    # used to create constraints and to convert the network-based solution to a bin packing solution
    arc_to_item = Dict{Arc,Int}()

    # item arcs
    for i in 1:num_items
        # collect is used to ensure we iterate only over vertices created in previous iterations
        current_positions = collect(keys(position_to_vertex))
        for p in current_positions
            if p + weights[i] <= capacity
                tail = position_to_vertex[p]
                head = get!(position_to_vertex, p + weights[i], new_vertex!(builder))
                arc = new_arc!(builder, tail, head; var_type = INTEGER)
                arc_to_item[arc] = i
                if p == 0
                    set_cost!(builder, arc, 1.0)
                end
            end
        end
    end

    # loss arcs
    sink = get!(position_to_vertex, capacity, new_vertex!(builder))
    for (p, vertex) in position_to_vertex
        if p < capacity
            new_arc!(builder, vertex, sink; var_type = INTEGER)
        end
    end

    # create a demand constraint for each item
    item_to_demand_constraint = Dict(
        i => new_constraint!(builder; lb = 1.0, ub = 1.0) for i in 1:num_items
    )

    # populate demand constraint coefficients
    for (arc, item) in arc_to_item
        set_constraint_coefficient!(builder, item_to_demand_constraint[item], arc, 1.0)
    end

    # new commodity from source to sink
    flow_capacity = num_items # enough to support any feasible solution
    commodity = new_commodity!(
        builder, position_to_vertex[0], sink, 0.0, flow_capacity
    )

    # optimizing the problem
    problem = get_problem(builder)
    solution = optimize!(problem, HiGHS.Optimizer)

    # converting network-flow solution to bin packing solution
    bin_solution_list = Vector{Vector{Int}}()
    for (path, flow) in get_path_to_flow_map(problem, solution, commodity)
        bin_solution = get_bin_solution(arc_to_item, path)
        num_bins = floor(Int, flow + 0.5) # rounding to deal with floating-point precision
        append!(bin_solution_list, fill(bin_solution, num_bins))
    end

    return bin_solution_list
end

function get_bin_solution(arc_to_item, path)
    bin_pattern = Vector{Int}()
    for arc in get_arcs(path)
        if haskey(arc_to_item, arc)
            item = arc_to_item[arc]
            push!(bin_pattern, item)
        end
    end
    return bin_pattern
end

capacity = 100
weights = [4, 6, 7, 24, 26, 32, 64, 68, 69]

solve_bin_packing(capacity, weights)
```
