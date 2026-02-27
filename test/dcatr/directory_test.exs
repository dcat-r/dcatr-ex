defmodule DCATR.DirectoryTest do
  use DCATR.Case

  doctest DCATR.Directory

  alias DCATR.Directory

  describe "new/1,2" do
    test "without members" do
      assert Directory.new(EX.Directory1) ==
               {:ok, %Directory{__id__: RDF.iri(EX.Directory1), members: []}}
    end

    test "with members" do
      graph1 = data_graph(id: EX.Graph1)
      graph2 = data_graph(id: EX.Graph2)

      assert Directory.new(EX.Directory1, members: [graph1, graph2]) ==
               {:ok,
                %Directory{
                  __id__: RDF.iri(EX.Directory1),
                  members: [graph1, graph2]
                }}
    end

    test "with mixed members (graphs and directories)" do
      graph = data_graph(id: EX.Graph1)
      sub_dir = directory(id: EX.SubDir)

      assert Directory.new(EX.Directory1, members: [graph, sub_dir]) ==
               {:ok,
                %Directory{
                  __id__: RDF.iri(EX.Directory1),
                  members: [graph, sub_dir]
                }}
    end
  end

  describe "load/2" do
    test "empty directory" do
      assert Directory.load(RDF.graph(), EX.Directory1) == {:ok, Directory.new!(EX.Directory1)}
    end

    test "directory with graph members" do
      rdf =
        RDF.graph([
          {EX.Graph1, RDF.type(), DCATR.DataGraph},
          {EX.Graph2, RDF.type(), DCATR.DataGraph},
          {EX.Directory1, RDF.type(), DCATR.Directory},
          {EX.Directory1, DCATR.member(), [EX.Graph1, EX.Graph2]}
        ])

      {:ok, dir} = Directory.load(rdf, EX.Directory1, depth: 1)

      assert dir.__id__ == RDF.iri(EX.Directory1)
      assert length(dir.members) == 2
      member_ids = Enum.map(dir.members, & &1.__id__) |> Enum.sort()
      assert member_ids == Enum.sort([RDF.iri(EX.Graph1), RDF.iri(EX.Graph2)])
    end
  end

  test "Grax.to_rdf/1" do
    graph1 = data_graph(id: EX.Graph1)
    dir = directory(id: EX.Directory1, members: [graph1])

    rdf = Grax.to_rdf!(dir)

    assert RDF.Graph.include?(rdf, {dir.__id__, RDF.type(), DCATR.Directory})
    assert RDF.Graph.include?(rdf, {dir.__id__, DCATR.member(), graph1.__id__})
  end

  describe "members/1" do
    test "returns all direct members" do
      graph = data_graph(id: EX.Graph1)
      sub_dir = directory(id: EX.SubDir)
      dir = directory(members: [graph, sub_dir])

      assert Directory.members(dir) == [graph, sub_dir]
    end

    test "returns empty list for empty directory" do
      assert Directory.members(directory(members: [])) == []
    end
  end

  describe "graphs/1" do
    test "returns only graph members" do
      graph1 = data_graph(id: EX.Graph1)
      graph2 = data_graph(id: EX.Graph2)
      sub_dir = directory(id: EX.SubDir)
      dir = directory(members: [graph1, sub_dir, graph2])

      assert Directory.graphs(dir) == [graph1, graph2]
    end

    test "returns empty list when no graphs" do
      sub_dir = directory(id: EX.SubDir)
      dir = directory(members: [sub_dir])

      assert Directory.graphs(dir) == []
    end
  end

  describe "directories/1" do
    test "returns only directory members" do
      graph = data_graph(id: EX.Graph1)
      sub_dir1 = directory(id: EX.SubDir1)
      sub_dir2 = directory(id: EX.SubDir2)
      dir = directory(members: [graph, sub_dir1, sub_dir2])

      assert Directory.directories(dir) == [sub_dir1, sub_dir2]
    end

    test "returns empty list when no directories" do
      graph = data_graph(id: EX.Graph1)
      dir = directory(members: [graph])

      assert Directory.directories(dir) == []
    end
  end

  describe "all_graphs/1" do
    test "returns graphs from nested directories" do
      graph1 = data_graph(id: EX.Graph1)
      graph2 = data_graph(id: EX.Graph2)
      nested_graph = data_graph(id: EX.Nested)
      inner_dir = directory(id: EX.InnerDir, members: [nested_graph])
      dir = directory(members: [graph1, inner_dir, graph2])

      assert Directory.all_graphs(dir) |> Enum.sort() == Enum.sort([graph1, graph2, nested_graph])
    end

    test "handles deeply nested directories" do
      deep_graph = data_graph(id: EX.Deep)
      level3 = directory(id: EX.Level3, members: [deep_graph])
      level2 = directory(id: EX.Level2, members: [level3])
      level1 = directory(id: EX.Level1, members: [level2])

      assert Directory.all_graphs(level1) == [deep_graph]
    end

    test "returns empty list for empty directory" do
      assert Directory.all_graphs(directory(members: [])) == []
    end

    test "returns empty list for directory with only subdirectories (no graphs)" do
      empty_sub = directory(id: EX.EmptySub, members: [])
      dir = directory(members: [empty_sub])

      assert Directory.all_graphs(dir) == []
    end
  end

  describe "all_members/1" do
    test "returns all elements recursively" do
      graph1 = data_graph(id: EX.Graph1)
      nested_graph = data_graph(id: EX.Nested)
      inner_dir = directory(id: EX.InnerDir, members: [nested_graph])
      dir = directory(members: [graph1, inner_dir])

      assert Directory.all_members(dir) |> Enum.sort() ==
               Enum.sort([graph1, inner_dir, nested_graph])
    end

    test "returns empty list for empty directory" do
      assert Directory.all_members(directory(members: [])) == []
    end
  end

  describe "find_graph/2" do
    test "finds graph in direct members" do
      graph = data_graph(id: EX.Graph1)
      dir = directory(members: [graph])

      assert Directory.find_graph(dir, EX.Graph1) == graph
    end

    test "finds graph in nested directory" do
      nested_graph = data_graph(id: EX.Nested)
      inner_dir = directory(id: EX.InnerDir, members: [nested_graph])
      dir = directory(members: [inner_dir])

      assert Directory.find_graph(dir, EX.Nested) == nested_graph
    end

    test "finds graph in deeply nested directory" do
      deep_graph = data_graph(id: EX.Deep)
      level3 = directory(id: EX.Level3, members: [deep_graph])
      level2 = directory(id: EX.Level2, members: [level3])
      level1 = directory(id: EX.Level1, members: [level2])

      assert Directory.find_graph(level1, EX.Deep) == deep_graph
    end

    test "returns nil for non-existent graph" do
      graph = data_graph(id: EX.Graph1)
      dir = directory(members: [graph])

      assert Directory.find_graph(dir, EX.NonExistent) == nil
    end

    test "does not match directory members" do
      sub_dir = directory(id: EX.SubDir)
      dir = directory(members: [sub_dir])

      assert Directory.find_graph(dir, EX.SubDir) == nil
    end
  end
end
