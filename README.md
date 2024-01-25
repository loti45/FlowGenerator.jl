[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://loti45.github.io/FlowGenerator.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://loti45.github.io/FlowGenerator.jl/dev/)
[![Build Status](https://github.com/loti45/FlowGenerator.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/loti45/FlowGenerator.jl/actions/workflows/CI.yml?query=branch%3Amain)

# FlowGenerator.jl
FlowGenerator is a network flow optimization library written in Julia. Its purpose is to solve complex, large-scale problems while offering a range of advanced features, including:
- **Multicommodity Flow**: Each commodity has a source, sink, flow demand and capacity.
- **Generalized Flows**: Allows flow loss or gain on arcs.
- **Hyper-Graph Support**: Handles hyper-arcs with one head and many tails.
- **Hybrid Arc Flow Domain**: Flexibility in defining the flow domain of each arc as either integer or continuous
- **Generic Linear Side-Constraints**: Allows to model demands, resource capacities, and other practical features as side-constraints.

The library can solve a network flow problem with all these features either by using a general-purpose MIP solver or by using our prototype solver that employs column generation and other state-of-the-art techniques for large-scale optimization.

## Example usage
### Basic usage
A basic problem is defined by a network comprising vertices, arcs (each with a cost), and at least one commodity. After installing FlowGenerator using the Julia REPL, the following steps create a simple network with 4 vertices and 5 arcs:
```julia
using FlowGenerator

builder = new_problem_builder()
v1 = new_vertex!(builder)
v2 = new_vertex!(builder)
v3 = new_vertex!(builder)
v4 = new_vertex!(builder)

arc1 = new_arc!(builder, v1, v2; cost = 1.0) # arc (v1, v2)
arc2 = new_arc!(builder, v1, v3; cost = 1.0) # arc (v1, v3)
arc3 = new_arc!(builder, v2, v3; cost = 4.0, capacity = 5.5) # arc (v2, v3)
arc4 = new_arc!(builder, v2, v4; cost = 1.0, capacity = 4.0) # arc (v2, v4)
arc5 = new_arc!(builder, v3, v4; cost = 2.0) # arc (v3, v4)
```

By default, each arc has zero cost, infinite capacity and continuous domain. The domain can be restricted to integer using the `var_type = INTEGER` parameter. For instance, to restrict `arc1` to have integer flow, we create it as:
``` julia
arc1 = new_arc!(builder, v1, v2; cost = 1.0, var_type = INTEGER)
```

After creating the network, we need to set at least one commodity to establish a flow source and sink. Below, we create a commodity with source `v1` and sink `v4` with flow demand `2.0` and flow capacity `4.0`:
``` julia
c1 = new_commodity!(builder, v1, v4, 5.0, 8.0)
```

While at least one commodity is required, we can define multiple commodities as needed:
``` julia
c2 = new_commodity!(builder, v2, v4, 2.0, 2.0)
c3 = new_commodity!(builder, v1, v3, 1.0, 4.0)
```

The flow conservation constraints are specific to each commodity, but all commodities share the same arc capacities.

To solve this problem, FlowGenerator relies on an external LP or MIP solver. We recommend using [HiGHS](https://github.com/jump-dev/HiGHS.jl) as a high-performance open-source solver. After including the solver package (e.g., `using HiGHS`), the problem can be solved as follows:
``` julia
problem = get_problem(builder)
solution = optimize!(problem, HiGHS.Optimizer)
```

The solution can be queried using the `get_flow` function to check the flow for each commodity and arc:
``` julia
@show get_flow(solution, c1, arc1) # outputs 2.0
@show get_flow(solution, c1, arc2) # outputs 3.0
@show get_flow(solution, c1, arc3) # outputs 0.0
@show get_flow(solution, c1, arc4) # outputs 2.0
@show get_flow(solution, c1, arc5) # outputs 3.0
```

We can also query the total flow on each arc:
``` julia
@show get_flow(solution, arc1) # outputs 2.0
@show get_flow(solution, arc2) # outputs 4.0
@show get_flow(solution, arc3) # outputs 0.0
@show get_flow(solution, arc4) # outputs 4.0
@show get_flow(solution, arc5) # outputs 3.0
```

The objective value of the solution can be accessed by:
``` julia
@show get_objective_value(solution) # outputs 16.0
```

### Advanced features
**Generalized Flows**: To account for flow loss or gain, we can assign a multiplier to each arc. This multiplier represents the amount of incoming flow consumed to generate one unit of outgoing flow. This is done by wrapping the tail and the multiplier in a pair. For example, to define a multiplier 4.0 for the tail of `arc5`, we define it as:
``` julia
arc5 = new_arc!(builder, (v3, 4.0), v4; cost = 2.0)
```

**Hyper-Graph Support**: FlowGenerator also supports hyper-arcs with multiple tails. This is done by providing a dictionary in the arc construction of each tail to its corresponding multiplier. For example:
``` julia
tail_to_multiplier_map = Dict(v2 => 1.0, v3 => 2.0)
arc5 = new_arc!(builder, tail_to_multiplier_map, v4; cost = 2.0)
```
**Generic Linear Side-Constraints**: We can add generic linear constraints on arc flows. For instance, to add a constraint like $3.0 \leq 3.5 \times arc1 - 1.0 \times arc2 \leq 5.0$:
``` julia
side_constraint = new_constraint!(builder; lb = 3.0, ub = 5.0)
set_constraint_coefficient!(builder, side_constraint, arc1, 3.5)
set_constraint_coefficient!(builder, side_constraint, arc2, -1.0)
```

### Other solver functions
**General-purpose MIP Solver**: While the `optimize!` function uses FlowGenerator's prototype solver, the problem can also be directly solved by an external MIP solver by calling:

``` julia
solution = optimize_by_mip_solver!(problem, HiGHS.Optimizer)
```

**Linear Relaxation**: FlowGenerator includes a function for solving the linear relaxation of the model. The `use_column_generation` keyword determines whether to use FlowGenerator's column generation algorithm or the LP solver of the external MIP solver:

``` julia
solution = optimize_linear_relaxation!(problem, HiGHS.Optimizer; use_column_generation = true)
```

**Reduced-cost Variable-fixing**: There's also a function to filter arcs based on their reduced costs. This function creates a modified copy of the problem, excluding arcs that cannot contribute to any solution with an objective value smaller than a specified `cutoff`:

``` julia
filtered_problem = filter_arcs_by_reduced_costs!(problem, HiGHS.Optimizer, cutoff)
```

## Theoretical and technical background
FlowGenerator originated as a prototyping tool to solve real-world problems in the industry. It represents a generalization of the Network Flow Framework (NF-F), which was proposed in:

de Lima, V.L., Iori, M. & Miyazawa, F.K. Exact solution of network flow models with strong relaxations. _Math. Program._ **197**, 813–846 (2023). https://doi.org/10.1007/s10107-022-01785-9.

NF-F solves network flow models with general linear side constraints, like the following:

$$\begin{align}
\min & \sum_{a \in A} c_{a} \varphi_{a} & \\
\text{s.t.:} & \sum_{a \in \delta^+(v)} \varphi_{a} = \sum_{a \in \delta^-(v)} \varphi_{a}, & \forall v \in V \setminus \{v^-, v^+\}, \\
& Q_i^- \leq \sum_{a \in A} q_{ia} \varphi_{a} \leq Q_i^+, & \forall i \in I, \\
& \varphi_{a} \in \mathbb{Z}_+, & \forall a \in A,
\end{align}$$

The framework is designed to address scalability issues in network flow models with strong relaxations. Although the model solved by NF-F is fairly generic, it does not cover some key practical features common in real-life problems. These features are integrated into the generalized model underlying FlowGenerator.

The model addressed by FlowGenerator is as follows:

$$\begin{align}
\min & \sum_{a \in A} \sum_{k \in K} c_{a} \varphi_{ak} & \\
\text{s.t.:} & \sum_{a \in \delta^+(v)} \mu_{a}(v)\varphi_{ak} = \sum_{a \in \delta^-(v)} \varphi_{ak}, & \forall k \in K, ~ \forall v \in V \setminus \{v_k^-, v_k^+\}, & ~~ (1) \\
& D_k^- \leq \sum_{a \in \delta^-(v)} \varphi_{ak} \leq D_k^+, & \forall k \in K, v = v_k^-, &~~(2) \\
& Q_i^- \leq \sum_{a \in A} \sum_{k \in K} q_{ia} \varphi_{ak} \leq Q_i^+, & \forall i \in I,& ~~ (3) \\
& 0 \leq \sum_{k \in K} \varphi_{ak} \leq b_a, & \forall a \in A, & ~~ (4) \\
& \varphi_{a} \in \mathbb{Z}_+, & \forall a \in A_Z, & ~~ (5)
\end{align}$$

In this model:
- Constraints (1) represent flow conservation, where $\mu_a(v)$ denotes the flow multiplier for vertex $v$ if $v$ a tail of arc $a$.
- Constraints (2) impose a demand and capacity of flow entering the sink of each commodity $k \in K$.
- Constraints (3) are equivalent to the generic linear side-constraints from NF-F.
- Constraints (4) model arc capacities.
- Constraints (5) enforce integrality constraints on a subset of arcs.

The user of FlowGenerator can choose to solve the model either directly through a general-purpose MIP solver or by utilizing our specialized algorithms, which include:
- **Column Generation**: Solves the linear relaxation of models with huge networks.
- **Reduced-Cost Variable-Fixing**: Filters the network by removing arcs that are proven to not improve the best known solution.
- **Bidirectional Shortest-Path Computation**: Enhances column generation and variable fixing computations.
- **Specialized Branching Scheme from NF-F**: Specifically designed for quickly finding high-quality heuristic solutions by relying on general-purpose MIP solvers. Particularly effective in models with strong relaxations.
## Limitations and future work

FlowGenerator has demonstrated high performance in problem classes that are well-addressed by NF-F. However, it is important to note that it is currently in a prototype stage and is continuously evolving. Some key areas for future development and current limitations include:

- **Acyclic Networks**: Like in NF-F, FlowGenerator's shortest-path computations assume acyclic networks. We are planning to integrate alternative shortest-path algorithms to overcome this limitation.

- **Strong Relaxations**: Currently, the branching and variable-fixing techniques are optimized for problems with strong relaxations. As cutting planes and other strengthening techniques are not yet implemented, strong relaxation remains crucial for best performance. Future research will focus on the development and integration of generic cutting planes to strengthen relaxations.

- **Hyper-Graph Limitations**: FlowGenerator extends NF-F key components to most new features, but it faces limitations with hyper-graphs. Specifically, the bidirectional shortest-path algorithm, which is a key component, could not be efficiently extended for hyper-graphs. We plan to research and implement techniques based on forward labelling that can serve as an efficient alternative to the bidirectional approach.

- **Resource-Constrained Network Flow**: FlowGenerator currently handles resource constraints through linear global constraints. However, certain resource constraints, like time or path-dependent resources, cannot always be modeled this way. Although users can enumerate resources directly in the network definition, this approach can lead to impractically large networks. The state of the art deals with this issues by enumerating resources dynamically. This is a future research direction.


There are many open directions for improvement in the library. As part of our commitment to solving challenging problems in practice, our medium-term plan is to enhance FlowGenerator's ability to find high-quality solutions quickly, rather than focusing on proving optimality. For that, our short-term goals include:

- **Efficient Column Generation**: Generally, the ability solving the root node efficiently is a core aspect in successful integer optimization solvers. To achieve this, we plan to significantly improve the efficiency of column generation. This enhancement may involve integrating methods from pure network flow literature, such as the network simplex algorithm, exploiting hybrid arc/path generation approaches, and dual stabilization techniques.
- **Primal Heuristics Based on Rounding and Diving**: We plan to extend the branching scheme inspired by NF-F with further rounding and diving techniques.

## Contributing
We welcome contributions and suggestions to make FlowGenerator better for the community. Both researchers and practitioners can contribute in the form of developing new features, creating application packages, testing, and establishing benchmark datasets.

