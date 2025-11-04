defmodule DCATR.GraphTest do
  use DCATR.Case

  doctest DCATR.Graph
  doctest DCATR.DataGraph
  doctest DCATR.SystemGraph
  doctest DCATR.ManifestGraph
  doctest DCATR.ServiceManifestGraph
  doctest DCATR.RepositoryManifestGraph

  alias DCATR.{
    Graph,
    DataGraph,
    SystemGraph,
    WorkingGraph,
    ManifestGraph,
    ServiceManifestGraph,
    RepositoryManifestGraph
  }

  describe "DCATR.Graph" do
    test "new/1" do
      assert Graph.new(EX.Graph1) == {:ok, %Graph{__id__: RDF.iri(EX.Graph1)}}
    end

    test "load/2" do
      assert RDF.graph({EX.Graph1, RDF.type(), DCATR.Graph})
             |> Graph.load(EX.Graph1) == {:ok, Graph.new!(EX.Graph1)}
    end
  end

  describe "DCATR.DataGraph" do
    test "new/1" do
      assert DataGraph.new(EX.DataGraph) == {:ok, %DataGraph{__id__: RDF.iri(EX.DataGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.DataGraph, RDF.type(), DCATR.DataGraph})
             |> DataGraph.load(EX.DataGraph) == {:ok, DataGraph.new!(EX.DataGraph)}
    end
  end

  describe "DCATR.ManifestGraph" do
    test "new/1" do
      assert ManifestGraph.new(EX.ManifestGraph) ==
               {:ok, %ManifestGraph{__id__: RDF.iri(EX.ManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ManifestGraph, RDF.type(), DCATR.ManifestGraph})
             |> ManifestGraph.load(EX.ManifestGraph) ==
               {:ok, ManifestGraph.new!(EX.ManifestGraph)}
    end
  end

  describe "DCATR.RepositoryManifestGraph" do
    test "new/1" do
      assert RepositoryManifestGraph.new(EX.ManifestGraph) ==
               {:ok, %RepositoryManifestGraph{__id__: RDF.iri(EX.ManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ManifestGraph, RDF.type(), DCATR.RepositoryManifestGraph})
             |> RepositoryManifestGraph.load(EX.ManifestGraph) ==
               {:ok, RepositoryManifestGraph.new!(EX.ManifestGraph)}
    end
  end

  describe "DCATR.ServiceManifestGraph" do
    test "new/1" do
      assert ServiceManifestGraph.new(EX.ServiceManifestGraph) ==
               {:ok, %ServiceManifestGraph{__id__: RDF.iri(EX.ServiceManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ServiceManifestGraph, RDF.type(), DCATR.ServiceManifestGraph})
             |> ServiceManifestGraph.load(EX.ServiceManifestGraph) ==
               {:ok, ServiceManifestGraph.new!(EX.ServiceManifestGraph)}
    end
  end

  describe "DCATR.SystemGraph" do
    test "new/1" do
      assert SystemGraph.new(EX.SystemGraph) ==
               {:ok, %SystemGraph{__id__: RDF.iri(EX.SystemGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.SystemGraph, RDF.type(), DCATR.SystemGraph})
             |> SystemGraph.load(EX.SystemGraph) == {:ok, SystemGraph.new!(EX.SystemGraph)}
    end
  end

  describe "DCATR.WorkingGraph" do
    test "new/1" do
      assert WorkingGraph.new(EX.WorkingGraph) ==
               {:ok, %WorkingGraph{__id__: RDF.iri(EX.WorkingGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.WorkingGraph, RDF.type(), DCATR.WorkingGraph})
             |> WorkingGraph.load(EX.WorkingGraph) == {:ok, WorkingGraph.new!(EX.WorkingGraph)}
    end
  end

  test "Grax.to_rdf/1" do
    graph = Graph.new!(EX.Graph)
    assert Grax.to_rdf(graph) == {:ok, RDF.graph({graph.__id__, RDF.type(), DCATR.Graph})}

    data_graph = example_data_graph()

    assert Grax.to_rdf(data_graph) ==
             {:ok, RDF.graph({data_graph.__id__, RDF.type(), DCATR.DataGraph})}

    working_graph = example_working_graph()

    assert Grax.to_rdf(working_graph) ==
             {:ok, RDF.graph({working_graph.__id__, RDF.type(), DCATR.WorkingGraph})}

    service_manifest = example_service_manifest_graph()

    assert Grax.to_rdf(service_manifest) ==
             {:ok, RDF.graph({service_manifest.__id__, RDF.type(), DCATR.ServiceManifestGraph})}

    assert Grax.to_rdf(example_repository_manifest_graph()) ==
             {:ok, RDF.graph({EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph})}

    assert Grax.to_rdf(example_system_graph()) ==
             {:ok, RDF.graph({EX.SystemGraph1, RDF.type(), DCATR.SystemGraph})}
  end
end
