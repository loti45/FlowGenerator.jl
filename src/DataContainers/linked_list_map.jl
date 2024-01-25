struct LinkedListNode{T}
    value::T
    next::Int  # Points to the next element index in the list
end

"""
    struct LinkedListMap{T}

A data structure that implements a map of integers to linked lists, with each list containing elements of type `T`.
It is designed to manage multiple linked lists efficiently by using a shared array of nodes (`nodes`) 
to store all elements of all lists, which improves memory allocation efficiency.

# Fields
- `list_head_index::Vector{Int}`: An array where each element is an integer representing the index of the first node 
  of a linked list in the `nodes` array. If the value is `-1`, it indicates that the linked list is empty.
- `nodes::Vector{LinkedListNode{T}}`: An array of `LinkedListNode{T}` that stores the nodes of all linked lists. 
  Each node contains a value of type `T` and an integer pointing to the next node in its list.

# Constructor
    LinkedListMap{T}(num_lists::Int) where {T}

Creates an instance of `LinkedListMap` with a specified number of lists (given by `num_lists`).
Each list is initialized as empty.

# Usage
- To add a value to a specific list, use `add_value!(list_map::LinkedListMap{T}, list_index::Int, value::T)`.
- To iterate over the elements of a list, obtain an iterator using `get_list_iter(list_map::LinkedListMap{T}, list_index::Int)`.
- To access a list iterator directly, use the indexing syntax with `list_map[index]`.

# Example
```julia
list_map = LinkedListMap{Int}(3)  # Create a map for 3 linked lists of integers
add_value!(list_map, 1, 10)       # Add the value 10 to the first list
add_value!(list_map, 1, 20)       # Add the value 20 to the first list
add_value!(list_map, 2, 30)       # Add the value 30 to the second list
for value in list_map[1]          # Iterate over the first list
    println(value)
end
```
This will output 10 and 20.

Note that this struct does not provide direct methods to remove nodes or to insert nodes at arbitrary positions. All nodes are added at the end (tail) of their respective lists.
"""
struct LinkedListMap{T}
    list_head_index::Vector{Int}  # Starting index for each list, -1 if the list is empty
    nodes::Vector{LinkedListNode{T}}

    function LinkedListMap{T}(num_lists::Int) where {T}
        list_head_index = fill(-1, num_lists)
        nodes = LinkedListNode{T}[]
        return new{T}(list_head_index, nodes)
    end
end

struct ListIterator{T}
    nodes::Vector{LinkedListNode{T}}
    current_index::Int
end

function add_value!(list_map::LinkedListMap{T}, list_index::Int, value::T) where {T}
    node = LinkedListNode(value, list_map.list_head_index[list_index])
    push!(list_map.nodes, node)
    list_map.list_head_index[list_index] = length(list_map.nodes)

    return nothing
end

# Pop all heads whose pred is true
function Base.pop!(list_map::LinkedListMap, pred::Function)
    for list_index in 1:length(list_map.list_head_index)
        value = first(list_map, list_index)
        if isnothing(value)
            continue
        end
        if pred(value)
            pop!(list_map, list_index)
        end
    end
    return nothing
end

function Base.pop!(list_map::LinkedListMap, index::Int)
    current = list_map.list_head_index[index]
    list_map.list_head_index[index] = list_map.nodes[current].next
    return list_map.nodes[current].value
end

function Base.first(list_map::LinkedListMap, index::Int)
    head = list_map.list_head_index[index]
    return head != -1 ? list_map.nodes[head].value : nothing
end

Base.IteratorSize(::Type{ListIterator{T}}) where {T} = Base.SizeUnknown()
Base.IteratorEltype(::Type{ListIterator{T}}) where {T} = Base.HasEltype()
Base.eltype(::Type{ListIterator{T}}) where {T} = T

function Base.iterate(
    iter::ListIterator{T}, current_index::Int = iter.current_index
) where {T}
    if current_index == -1
        return nothing
    end

    node = iter.nodes[current_index]
    return node.value, node.next
end

function get_list_iter(list_map::LinkedListMap{T}, list_index::Int) where {T}
    start_index = list_map.list_head_index[list_index]
    return ListIterator{T}(list_map.nodes, start_index)
end

Base.getindex(lm::LinkedListMap, in::Int) = get_list_iter(lm, in)
Base.getindex(lm::LinkedListMap, obj) = get_list_iter(lm, obj.index)
