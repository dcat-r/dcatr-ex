defmodule DCATR.DatasetTest do
  use DCATR.Case

  doctest DCATR.Dataset

  alias DCATR.Dataset

  describe "new/1,2" do
    test "without graphs" do
      assert Dataset.new(EX.Dataset1) ==
               {:ok, %Dataset{__id__: RDF.iri(EX.Dataset1), graphs: [], directories: []}}
    end

    test "with data graphs" do
      graphs = example_data_graphs()

      assert Dataset.new(EX.Dataset1, graphs: graphs) ==
               {:ok, %Dataset{__id__: RDF.iri(EX.Dataset1), graphs: graphs, directories: []}}
    end

    test "with directories" do
      dir = example_directory()

      assert Dataset.new(EX.Dataset1, directories: [dir]) ==
               {:ok, %Dataset{__id__: RDF.iri(EX.Dataset1), graphs: [], directories: [dir]}}
    end
  end

  describe "load/2" do
    test "minimal dataset" do
      assert Dataset.load(RDF.graph(), EX.Dataset1) == {:ok, Dataset.new!(EX.Dataset1)}
    end

    test "dataset with all properties" do
      assert RDF.graph([
               {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
               {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
               {EX.Dataset1, RDF.type(), DCATR.Dataset},
               {EX.Dataset1, DCATR.dataGraph(), [EX.DataGraph1, EX.DataGraph2]}
             ])
             |> Dataset.load(EX.Dataset1) == {:ok, example_dataset()}
    end

    test "DataGraphs linked via dcatr:member appear in graphs" do
      graph =
        RDF.graph([
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.member(), [EX.DataGraph1, EX.DataGraph2]}
        ])

      assert Dataset.load(graph, EX.Dataset1, depth: 1) ==
               {:ok,
                example_dataset()
                |> Grax.add_additional_statements(%{
                  DCATR.member() => [EX.DataGraph1, EX.DataGraph2]
                })}
    end

    test "mixed: some via dcatr:dataGraph, some via dcatr:member" do
      graph =
        RDF.graph([
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph1},
          {EX.Dataset1, DCATR.member(), [EX.DataGraph1, EX.DataGraph2]}
        ])

      {:ok, loaded} = Dataset.load(graph, EX.Dataset1, depth: 1)

      assert length(loaded.graphs) == 2
      loaded_ids = Enum.map(loaded.graphs, & &1.__id__) |> MapSet.new()

      assert MapSet.equal?(
               loaded_ids,
               MapSet.new([RDF.iri(EX.DataGraph1), RDF.iri(EX.DataGraph2)])
             )
    end

    test "Directories linked via dcatr:member appear in directories" do
      graph =
        RDF.graph([
          {EX.SubDir, RDF.type(), DCATR.Directory},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.member(), EX.SubDir}
        ])

      {:ok, loaded} = Dataset.load(graph, EX.Dataset1, depth: 1)

      assert length(loaded.directories) == 1
      [dir] = loaded.directories
      assert dir.__id__ == RDF.iri(EX.SubDir)
    end

    test "mixed directories: some via dcatr:directory, some via dcatr:member" do
      graph =
        RDF.graph([
          {EX.Dir1, RDF.type(), DCATR.Directory},
          {EX.Dir2, RDF.type(), DCATR.Directory},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.directory(), EX.Dir1},
          {EX.Dataset1, DCATR.member(), [EX.Dir1, EX.Dir2]}
        ])

      {:ok, loaded} = Dataset.load(graph, EX.Dataset1, depth: 1)

      assert length(loaded.directories) == 2
      dir_ids = Enum.map(loaded.directories, & &1.__id__) |> MapSet.new()
      assert MapSet.equal?(dir_ids, MapSet.new([RDF.iri(EX.Dir1), RDF.iri(EX.Dir2)]))
    end

    test "raises ArgumentError when loading from RDF.Description" do
      desc = RDF.description(EX.Dataset1, init: {EX.Dataset1, RDF.type(), DCATR.Dataset})
      assert_raise ArgumentError, fn -> Dataset.load(desc, EX.Dataset1) end
    end
  end

  test "Grax.to_rdf/1" do
    graph1 = data_graph()
    graph2 = data_graph()
    dataset = dataset(graphs: [graph1, graph2])

    rdf = Grax.to_rdf!(dataset)

    assert RDF.Graph.include?(rdf, {dataset.__id__, RDF.type(), DCATR.Dataset})
    assert RDF.Graph.include?(rdf, {dataset.__id__, DCATR.dataGraph(), graph1.__id__})
    assert RDF.Graph.include?(rdf, {dataset.__id__, DCATR.dataGraph(), graph2.__id__})
  end

  describe "graph/2" do
    setup :example_dataset_scenario

    test "returns graph by IRI", %{dataset: dataset, data_graphs: [graph1 | _]} do
      assert Dataset.graph(dataset, graph1.__id__) == graph1
      assert Dataset.graph(dataset, EX.DataGraph1) == graph1
    end

    test "returns graph by URI string", %{dataset: dataset, data_graphs: [_, graph2]} do
      uri_string = to_string(graph2.__id__)
      assert Dataset.graph(dataset, uri_string) == graph2
    end

    test "returns nil for non-existent graph", %{dataset: dataset} do
      assert Dataset.graph(dataset, EX.NonExistent) == nil
    end

    test "handles dataset without graphs" do
      assert Dataset.graph(dataset(), EX.Any) == nil
    end
  end

  describe "graphs/1" do
    test "returns all graphs" do
      assert Dataset.graphs(example_dataset()) == example_data_graphs()
    end

    test "returns empty list for dataset without graphs" do
      assert Dataset.graphs(dataset()) == []
    end
  end

  describe "directories/1" do
    test "returns all directories" do
      dir = example_directory()
      ds = dataset(directories: [dir])

      assert Dataset.directories(ds) == [dir]
    end

    test "returns empty list for dataset without directories" do
      assert Dataset.directories(dataset()) == []
    end
  end

  describe "has_graph?/2" do
    setup :example_dataset_scenario

    test "returns true when graph exists", %{dataset: dataset, data_graphs: [graph1 | _]} do
      assert Dataset.has_graph?(dataset, graph1.__id__) == true
      assert Dataset.has_graph?(dataset, EX.DataGraph1) == true
    end

    test "returns false when graph does not exist", %{dataset: dataset} do
      assert Dataset.has_graph?(dataset, EX.NonExistent) == false
    end

    test "returns false for empty dataset" do
      assert Dataset.has_graph?(dataset(), EX.Any) == false
    end

    test "finds graph in directory" do
      dir_graph = data_graph(id: EX.DirGraph)
      dir = directory(members: [dir_graph])
      ds = dataset(directories: [dir])

      assert Dataset.has_graph?(ds, EX.DirGraph) == true
    end
  end

  describe "all_graphs/1" do
    test "returns only direct graphs when no directories" do
      ds = example_dataset()

      assert Dataset.all_graphs(ds) == example_data_graphs()
    end

    test "returns direct graphs plus graphs from directories" do
      direct_graph = data_graph(id: EX.Direct)
      dir_graph = data_graph(id: EX.DirGraph)
      dir = directory(members: [dir_graph])
      ds = dataset(graphs: [direct_graph], directories: [dir])

      all = Dataset.all_graphs(ds)
      assert length(all) == 2
      assert direct_graph in all
      assert dir_graph in all
    end

    test "returns graphs from nested directories" do
      nested_graph = data_graph(id: EX.Nested)
      inner_dir = directory(id: EX.InnerDir, members: [nested_graph])
      outer_dir = directory(id: EX.OuterDir, members: [inner_dir])
      ds = dataset(directories: [outer_dir])

      assert Dataset.all_graphs(ds) == [nested_graph]
    end
  end

  describe "find_graph/2" do
    test "finds graph among direct graphs" do
      ds = example_dataset()
      [graph1 | _] = example_data_graphs()

      assert Dataset.find_graph(ds, EX.DataGraph1) == graph1
    end

    test "finds graph in directory" do
      dir_graph = data_graph(id: EX.DirGraph)
      dir = directory(members: [dir_graph])
      ds = dataset(directories: [dir])

      assert Dataset.find_graph(ds, EX.DirGraph) == dir_graph
    end

    test "finds graph in nested directory" do
      nested_graph = data_graph(id: EX.Nested)
      inner_dir = directory(id: EX.InnerDir, members: [nested_graph])
      outer_dir = directory(id: EX.OuterDir, members: [inner_dir])
      ds = dataset(directories: [outer_dir])

      assert Dataset.find_graph(ds, EX.Nested) == nested_graph
    end

    test "returns nil for non-existent graph" do
      ds = example_dataset()

      assert Dataset.find_graph(ds, EX.NonExistent) == nil
    end

    test "prefers direct graphs over directory graphs" do
      direct_graph = data_graph(id: EX.Graph1)
      dir_graph = data_graph(id: EX.Graph1)
      dir = directory(members: [dir_graph])
      ds = dataset(graphs: [direct_graph], directories: [dir])

      assert Dataset.find_graph(ds, EX.Graph1) == direct_graph
    end
  end
end
