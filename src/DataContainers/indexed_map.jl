"""
IndexedMap{K,V} is a (partial) implementation of AbstractDict{K,V}.
It provides fast index-based access and allows a default value to be specified.
It supports efficient addition and removal of key-value pairs.
"""
mutable struct IndexedMap{K,V} <: AbstractDict{K,V}
    keys::Vector{K}
    values::Vector{V}
    default_value::V
    key_last_set::Vector{Int}
    reset_count::Int

    function IndexedMap{K,V}(
        keys::Vector{K}, value_function::Union{Function,Nothing} = nothing; default
    ) where {K,V}
        max_index = get_max_index(keys)
        values = Vector{V}(undef, max_index)

        key_last_set = fill(0, max_index)
        if !isnothing(value_function)
            for key in keys
                values[key.index] = value_function(key)
                key_last_set[key.index] = 1
            end
        end
        return new{K,V}(keys, values, default, key_last_set, 1)
    end
end

function get_max_index(keys)
    output = 0
    for key in keys
        if key.index > output
            output = key.index
        end
    end
    return output
end

function reset!(map::IndexedMap{K,V}) where {K,V}
    map.reset_count += 1
    return nothing
end

@inline function is_in_boundaries(map::IndexedMap{K,V}, key::K) where {K,V}
    return key.index >= 1 && key.index <= length(map.keys)
end

@inline function Base.haskey(map::IndexedMap{K,V}, key::K) where {K,V}
    return is_in_boundaries(map, key) && key == map.keys[key.index]
end

@inline function Base.setindex!(map::IndexedMap{K,V}, value::V, key::K) where {K,V}
    map.values[key.index] = value
    map.key_last_set[key.index] = map.reset_count
    return nothing
end

@inline function Base.getindex(map::IndexedMap{K,V}, key::K) where {K,V}
    return if map.key_last_set[key.index] == map.reset_count
        map.values[key.index]
    else
        map.default_value
    end
end

@inline function Base.keys(map::IndexedMap{K,V}) where {K,V}
    return map.keys
end

@inline function Base.values(map::IndexedMap{K,V}) where {K,V}
    return map.values
end

@inline function Base.length(map::IndexedMap{K,V}) where {K,V}
    return length(map.keys)
end
