# Test for LinkedListMapNode Creation
@testset "LinkedListNode Creation" begin
    node = FlowGenerator.DataContainers.LinkedListNode(10, 2)
    @test node.value == 10
    @test node.next == 2
end

# Test for LinkedListMap Creation
@testset "LinkedListMap Creation" begin
    lc = FlowGenerator.DataContainers.LinkedListMap{Int}(3)
    @test length(lc.list_head_index) == 3
    @test all(x -> x == -1, lc.list_head_index)
end

# Test Adding Values with FlowGenerator.add_value!
@testset "Adding Values" begin
    lc = FlowGenerator.DataContainers.LinkedListMap{Int}(3)
    FlowGenerator.add_value!(lc, 1, 5)
    FlowGenerator.add_value!(lc, 2, 10)
    FlowGenerator.add_value!(lc, 1, 15)

    @test lc.nodes[1].value == 5
    @test lc.nodes[2].value == 10
    @test lc.nodes[3].value == 15
    @test lc.list_head_index[1] == 3
    @test lc.list_head_index[2] == 2
end

# Test Iteration with ListIterator
@testset "Iteration with ListIterator" begin
    lc = FlowGenerator.DataContainers.LinkedListMap{Int}(2)
    FlowGenerator.add_value!(lc, 1, 5)
    FlowGenerator.add_value!(lc, 1, 10)
    FlowGenerator.add_value!(lc, 1, 13)

    values = [value for value in lc[1]]

    @test values == [13, 10, 5]
end

# Test Indexing with Base.getindex
@testset "Indexing with Base.getindex" begin
    lc = FlowGenerator.DataContainers.LinkedListMap{Int}(2)
    FlowGenerator.add_value!(lc, 1, 5)
    FlowGenerator.add_value!(lc, 1, 4)
    FlowGenerator.add_value!(lc, 2, 10)

    @test collect(lc[1]) == [4, 5]
    @test collect(lc[2]) == [10]
end
