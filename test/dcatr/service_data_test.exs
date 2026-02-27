defmodule DCATR.ServiceDataTest do
  use DCATR.Case

  doctest DCATR.ServiceData

  alias DCATR.ServiceData

  describe "new/1,2" do
    test "with IRI" do
      manifest_graph_id = RDF.bnode("service-manifest")

      assert ServiceData.new(EX.ServiceData1, manifest_graph: manifest_graph_id) ==
               {:ok,
                %ServiceData{
                  __id__: RDF.iri(EX.ServiceData1),
                  manifest_graph: manifest_graph_id,
                  working_graphs: [],
                  system_graphs: []
                }}
    end

    test "with blank node" do
      bnode = bnode()
      manifest = service_manifest_graph()

      assert ServiceData.new(bnode, manifest_graph: manifest) ==
               {:ok,
                %ServiceData{
                  __id__: bnode,
                  manifest_graph: manifest,
                  working_graphs: [],
                  system_graphs: []
                }}
    end

    test "with all graphs given" do
      bnode = bnode()
      manifest = service_manifest_graph()
      working1 = working_graph()
      working2 = working_graph()
      system1 = system_graph()
      system2 = system_graph()

      assert ServiceData.new(bnode,
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
      manifest_graph_id = ~B<ServiceManifest>

      assert RDF.graph([{EX.ServiceData1, DCATR.serviceManifestGraph(), manifest_graph_id}])
             |> ServiceData.load(EX.ServiceData1, depth: 99) ==
               {:ok,
                ServiceData.new!(EX.ServiceData1,
                  manifest_graph: service_manifest_graph(id: manifest_graph_id)
                )}
    end

    test "service data with all properties" do
      assert RDF.graph([
               {~B<ServiceManifest>, RDF.type(), DCATR.ServiceManifestGraph},
               {~B<WorkingGraph1>, RDF.type(), DCATR.WorkingGraph},
               {~B<WorkingGraph2>, RDF.type(), DCATR.WorkingGraph},
               {EX.LocalSystemGraph, RDF.type(), DCATR.SystemGraph},
               {EX.ServiceData1, RDF.type(), DCATR.ServiceData},
               {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
               {EX.ServiceData1, DCATR.serviceWorkingGraph(),
                [~B<WorkingGraph1>, ~B<WorkingGraph2>]},
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

    test "returns manifest with :service_manifest selector", %{
      service_data: service_data,
      service_manifest: manifest
    } do
      assert ServiceData.graph(service_data, :service_manifest) == manifest
    end

    test "returns graph by ID", %{
      service_data: service_data,
      service_manifest: manifest,
      working_graphs: [working1, working2],
      local_system_graphs: [system1]
    } do
      assert ServiceData.graph(service_data, manifest.__id__) == manifest
      assert ServiceData.graph(service_data, ~B<ServiceManifest>) == manifest
      assert ServiceData.graph(service_data, working1.__id__) == working1
      assert ServiceData.graph(service_data, RDF.bnode(:WorkingGraph2)) == working2
      assert ServiceData.graph(service_data, EX.LocalSystemGraph) == system1
      assert ServiceData.graph(service_data, system1.__id__) == system1
    end

    test "returns nil for non-existent graph", %{service_data: service_data} do
      assert ServiceData.graph(service_data, EX.NonExistent) == nil
    end
  end

  test "resolve_graph_selector/2" do
    service_data = example_service_data()

    assert ServiceData.resolve_graph_selector(service_data, :service_manifest) ==
             service_data.manifest_graph

    assert ServiceData.resolve_graph_selector(service_data, :unknown_selector) == :undefined
  end

  describe "graphs/1" do
    setup :example_service_data_scenario

    test "returns all graphs", %{
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

    test "handles ServiceData with only manifest", %{service_manifest: manifest} do
      assert service_data(manifest_graph: manifest) |> ServiceData.graphs() == [manifest]
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
      service_manifest: manifest,
      working_graphs: [working1 | _],
      local_system_graphs: [system1]
    } do
      assert ServiceData.has_graph?(service_data, working1.__id__)
      assert ServiceData.has_graph?(service_data, system1.__id__)
      assert ServiceData.has_graph?(service_data, manifest.__id__)
    end

    test "returns true for :service_manifest selector", %{service_data: service_data} do
      assert ServiceData.has_graph?(service_data, :service_manifest)
    end

    test "returns false for non-existent graphs", %{service_data: service_data} do
      refute ServiceData.has_graph?(service_data, EX.NonExistent)
    end
  end
end
