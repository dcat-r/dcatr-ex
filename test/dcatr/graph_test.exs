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
    test "build/1" do
      assert Graph.build(EX.Graph1) == {:ok, %Graph{__id__: RDF.iri(EX.Graph1)}}
    end

    test "load/2" do
      assert RDF.graph({EX.Graph1, RDF.type(), DCATR.Graph})
             |> Graph.load(EX.Graph1) == {:ok, Graph.build!(EX.Graph1)}
    end
  end

  describe "DCATR.DataGraph" do
    test "build/1" do
      assert DataGraph.build(EX.DataGraph) == {:ok, %DataGraph{__id__: RDF.iri(EX.DataGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.DataGraph, RDF.type(), DCATR.DataGraph})
             |> DataGraph.load(EX.DataGraph) == {:ok, DataGraph.build!(EX.DataGraph)}
    end
  end

  describe "DCATR.ManifestGraph" do
    test "build/1" do
      assert ManifestGraph.build(EX.ManifestGraph) ==
               {:ok, %ManifestGraph{__id__: RDF.iri(EX.ManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ManifestGraph, RDF.type(), DCATR.ManifestGraph})
             |> ManifestGraph.load(EX.ManifestGraph) ==
               {:ok, ManifestGraph.build!(EX.ManifestGraph)}
    end
  end

  describe "DCATR.RepositoryManifestGraph" do
    test "build/1" do
      assert RepositoryManifestGraph.build(EX.ManifestGraph) ==
               {:ok, %RepositoryManifestGraph{__id__: RDF.iri(EX.ManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ManifestGraph, RDF.type(), DCATR.RepositoryManifestGraph})
             |> RepositoryManifestGraph.load(EX.ManifestGraph) ==
               {:ok, RepositoryManifestGraph.build!(EX.ManifestGraph)}
    end
  end

  describe "DCATR.ServiceManifestGraph" do
    test "build/1" do
      assert ServiceManifestGraph.build(EX.ServiceManifestGraph) ==
               {:ok, %ServiceManifestGraph{__id__: RDF.iri(EX.ServiceManifestGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.ServiceManifestGraph, RDF.type(), DCATR.ServiceManifestGraph})
             |> ServiceManifestGraph.load(EX.ServiceManifestGraph) ==
               {:ok, ServiceManifestGraph.build!(EX.ServiceManifestGraph)}
    end
  end

  describe "DCATR.SystemGraph" do
    test "build/1" do
      assert SystemGraph.build(EX.SystemGraph) ==
               {:ok, %SystemGraph{__id__: RDF.iri(EX.SystemGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.SystemGraph, RDF.type(), DCATR.SystemGraph})
             |> SystemGraph.load(EX.SystemGraph) == {:ok, SystemGraph.build!(EX.SystemGraph)}
    end
  end

  describe "DCATR.WorkingGraph" do
    test "build/1" do
      assert WorkingGraph.build(EX.WorkingGraph) ==
               {:ok, %WorkingGraph{__id__: RDF.iri(EX.WorkingGraph)}}
    end

    test "load/2" do
      assert RDF.graph({EX.WorkingGraph, RDF.type(), DCATR.WorkingGraph})
             |> WorkingGraph.load(EX.WorkingGraph) == {:ok, WorkingGraph.build!(EX.WorkingGraph)}
    end
  end

  test "Grax.to_rdf/1" do
    graph = Graph.build!(EX.Graph)
    assert Grax.to_rdf(graph) == {:ok, RDF.graph({graph.__id__, RDF.type(), DCATR.Graph})}

    assert Grax.to_rdf(example_data_graph()) ==
             {:ok, RDF.graph({EX.DataGraph1, RDF.type(), DCATR.DataGraph})}

    assert Grax.to_rdf(example_working_graph()) ==
             {:ok, RDF.graph({EX.WorkingGraph1, RDF.type(), DCATR.WorkingGraph})}

    assert Grax.to_rdf(example_service_manifest_graph()) ==
             {:ok, RDF.graph({EX.ServiceManifest, RDF.type(), DCATR.ServiceManifestGraph})}

    assert Grax.to_rdf(example_repository_manifest_graph()) ==
             {:ok, RDF.graph({EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph})}

    assert Grax.to_rdf(example_system_graph()) ==
             {:ok, RDF.graph({EX.SystemGraph1, RDF.type(), DCATR.SystemGraph})}
  end
end
