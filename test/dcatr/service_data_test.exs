defmodule DCATR.ServiceDataTest do
  use DCATR.Case

  doctest DCATR.ServiceData

  alias DCATR.ServiceData

  describe "build/1,2" do
    test "with IRI" do
      assert ServiceData.build(EX.ServiceData1) ==
               {:ok,
                %ServiceData{
                  __id__: RDF.iri(EX.ServiceData1),
                  manifest_graph: nil,
                  working_graphs: [],
                  system_graphs: []
                }}
    end

    test "with blank node" do
      bnode = bnode()
      assert ServiceData.build(bnode) == {:ok, %ServiceData{__id__: bnode}}
    end

    test "with all graphs given" do
      bnode = bnode()
      manifest = service_manifest_graph()
      working1 = working_graph()
      working2 = working_graph()
      system1 = system_graph()
      system2 = system_graph()

      assert ServiceData.build(bnode,
               manifest_graph: manifest,
               working_graphs: [working1, working2],
               system_graphs: [system1, system2]
             ) ==
               {:ok,
                %ServiceData{
                  __id__: bnode,
                  manifest_graph: manifest,
                  working_graphs: [working1, working2],
                  system_graphs: [system1, system2]
                }}
    end
  end

  describe "load/2" do
    test "minimal service data" do
      assert ServiceData.load(RDF.graph(), EX.ServiceData1) ==
               {:ok, ServiceData.build!(EX.ServiceData1)}
    end

    test "service data with all properties" do
      assert RDF.graph([
               {EX.ServiceManifest, RDF.type(), DCATR.ServiceManifestGraph},
               {EX.WorkingGraph1, RDF.type(), DCATR.WorkingGraph},
               {EX.WorkingGraph2, RDF.type(), DCATR.WorkingGraph},
               {EX.LocalSystemGraph, RDF.type(), DCATR.SystemGraph},
               {EX.ServiceData1, RDF.type(), DCATR.ServiceData},
               {EX.ServiceData1, DCATR.serviceManifestGraph(), EX.ServiceManifest},
               {EX.ServiceData1, DCATR.serviceWorkingGraph(),
                [EX.WorkingGraph1, EX.WorkingGraph2]},
               {EX.ServiceData1, DCATR.serviceSystemGraph(), EX.LocalSystemGraph}
             ])
             |> ServiceData.load(EX.ServiceData1, depth: 99) == {:ok, example_service_data()}
    end
  end

  test "Grax.to_rdf/1" do
    manifest = service_manifest_graph()
    working = working_graph()
    system = system_graph()

    service_data =
      service_data(
        manifest_graph: manifest,
        working_graphs: [working],
        system_graphs: [system]
      )

    rdf = Grax.to_rdf!(service_data)

    assert RDF.Graph.include?(rdf, {service_data.__id__, RDF.type(), DCATR.ServiceData})

    assert RDF.Graph.include?(
             rdf,
             {service_data.__id__, DCATR.serviceManifestGraph(), manifest.__id__}
           )

    assert RDF.Graph.include?(
             rdf,
             {service_data.__id__, DCATR.serviceWorkingGraph(), working.__id__}
           )

    assert RDF.Graph.include?(
             rdf,
             {service_data.__id__, DCATR.serviceSystemGraph(), system.__id__}
           )
  end

  describe "graph/2" do
    setup :example_service_data_scenario

    test "returns manifest with :manifest selector", %{
      service_data: service_data,
      service_manifest: manifest
    } do
      assert ServiceData.graph(service_data, :manifest) == manifest
    end

    test "returns graph by ID", %{
      service_data: service_data,
      service_manifest: manifest,
      working_graphs: [working1, working2],
      local_system_graphs: [system1]
    } do
      assert ServiceData.graph(service_data, manifest.__id__) == manifest
      assert ServiceData.graph(service_data, EX.ServiceManifest) == manifest
      assert ServiceData.graph(service_data, working1.__id__) == working1
      assert ServiceData.graph(service_data, EX.WorkingGraph2) == working2
      assert ServiceData.graph(service_data, EX.LocalSystemGraph) == system1
      assert ServiceData.graph(service_data, system1.__id__) == system1
    end

    test "returns nil for non-existent graph", %{service_data: service_data} do
      assert ServiceData.graph(service_data, EX.NonExistent) == nil
    end

    test "handles ServiceData without manifest" do
      assert ServiceData.graph(empty_service_data(), :manifest) == nil
    end
  end

  describe "graphs/2" do
    setup :example_service_data_scenario

    test "returns all graphs without options", %{
      service_data: service_data,
      service_manifest: manifest,
      working_graphs: [working1, working2],
      local_system_graphs: [system1]
    } do
      graphs = ServiceData.graphs(service_data)
      assert length(graphs) == 4
      assert manifest in graphs
      assert working1 in graphs
      assert working2 in graphs
      assert system1 in graphs
    end

    test "filters by type :manifest", %{service_data: service_data, service_manifest: manifest} do
      assert ServiceData.graphs(service_data, type: :manifest) == [manifest]
    end

    test "filters by type :working", %{service_data: service_data, working_graphs: working_graphs} do
      assert ServiceData.graphs(service_data, type: :working) == working_graphs
    end

    test "filters by type :system", %{service_data: service_data, local_system_graphs: system} do
      assert ServiceData.graphs(service_data, type: :system) == system
    end

    test "handles ServiceData with only manifest", %{service_manifest: manifest} do
      assert service_data(manifest_graph: manifest) |> ServiceData.graphs() == [manifest]
    end

    test "filters by multiple types", %{
      service_data: service_data,
      service_manifest: manifest,
      working_graphs: [working1, working2],
      local_system_graphs: [system1]
    } do
      graphs = ServiceData.graphs(service_data, type: [:manifest, :working])
      assert length(graphs) == 3
      assert manifest in graphs
      assert working1 in graphs
      assert working2 in graphs
      refute system1 in graphs

      graphs = ServiceData.graphs(service_data, type: [:working, :system])
      assert length(graphs) == 3
      assert working1 in graphs
      assert working2 in graphs
      assert system1 in graphs
      refute manifest in graphs

      graphs = ServiceData.graphs(service_data, type: [:manifest, :working, :system])
      assert length(graphs) == 4
      assert manifest in graphs
      assert working1 in graphs
      assert working2 in graphs
      assert system1 in graphs
    end

    test "handles empty list of types", %{service_data: service_data} do
      assert ServiceData.graphs(service_data, type: []) == []
    end

    test "handles list with unknown types", %{service_data: service_data} do
      assert ServiceData.graphs(service_data, type: [:unknown, :invalid]) == []
    end

    test "handles mixed valid and invalid types in list", %{
      service_data: service_data,
      service_manifest: manifest
    } do
      assert ServiceData.graphs(service_data, type: [:manifest, :unknown]) == [manifest]
    end

    test "returns empty list for unknown type filter", %{service_data: service_data} do
      assert ServiceData.graphs(service_data, type: :unknown) == []
    end

    test "handles empty ServiceData" do
      assert empty_service_data() |> ServiceData.graphs() == []
    end
  end

  describe "working_graphs/1" do
    working_graphs = example_working_graphs()

    assert service_data(working_graphs: working_graphs) |> ServiceData.working_graphs() ==
             working_graphs

    assert service_data(working_graphs: []) |> ServiceData.working_graphs() == []
  end

  test "system_graphs/1" do
    system_graphs = example_system_graphs()

    assert service_data(system_graphs: system_graphs)
           |> ServiceData.system_graphs() == system_graphs

    assert service_data(system_graphs: []) |> ServiceData.system_graphs() == []
  end

  describe "has_graph?/2" do
    setup :example_service_data_scenario

    test "returns true for existing graphs by ID", %{
      service_data: service_data,
      working_graphs: [working1 | _],
      local_system_graphs: [system1]
    } do
      assert ServiceData.has_graph?(service_data, working1.__id__)
      assert ServiceData.has_graph?(service_data, system1.__id__)
      assert ServiceData.has_graph?(service_data, EX.ServiceManifest)
    end

    test "returns true for manifest selector", %{service_data: service_data} do
      assert ServiceData.has_graph?(service_data, :manifest)
    end

    test "returns false for non-existent graphs", %{service_data: service_data} do
      refute ServiceData.has_graph?(service_data, EX.NonExistent)
    end

    test "handles ServiceData without any graphs" do
      service_data = empty_service_data()
      refute ServiceData.has_graph?(service_data, :manifest)
      refute ServiceData.has_graph?(service_data, EX.Any)
    end
  end
end
