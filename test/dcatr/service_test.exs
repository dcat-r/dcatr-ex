defmodule DCATR.ServiceTest do
  use DCATR.Case

  doctest DCATR.Service

  alias DCATR.Service

  test "build/1,2" do
    repository = repository()
    local_data = service_data()

    assert Service.build(EX.Service1,
             repository: repository,
             local_data: local_data
           ) ==
             {:ok,
              %Service{
                __id__: RDF.iri(EX.Service1),
                repository: repository,
                local_data: local_data,
                graph_names: %{},
                graph_names_by_id: %{}
              }}
  end

  describe "load/2" do
    test "minimal service" do
      assert RDF.graph([
               {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
               {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
               {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1}
             ])
             |> Service.load(EX.Service1, depth: 99) ==
               {:ok,
                Service.build!(EX.Service1,
                  repository:
                    empty_repository(id: EX.Repository1, dataset: dataset(id: EX.Dataset1)),
                  local_data: empty_service_data(id: EX.ServiceData1)
                )}
    end

    @tag skip: "TODO: fix service graph metadata leak into graph schemas"
    test "service with all properties" do
      assert RDF.graph([
               {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
               {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
               {EX.Dataset1, RDF.type(), DCATR.Dataset},
               {EX.Dataset1, DCATR.dataGraph(), [EX.DataGraph1, EX.DataGraph2]},
               {EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph},
               {EX.SystemGraph1, RDF.type(), DCATR.SystemGraph},
               {EX.SystemGraph2, RDF.type(), DCATR.SystemGraph},
               {EX.Repository1, RDF.type(), DCATR.Repository},
               {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
               {EX.Repository1, DCATR.repositoryManifest(), EX.RepositoryManifest},
               {EX.Repository1, DCATR.repositorySystemGraph(),
                [EX.SystemGraph1, EX.SystemGraph2]},
               {EX.ServiceManifest, RDF.type(), DCATR.ServiceManifestGraph},
               {EX.WorkingGraph1, RDF.type(), DCATR.WorkingGraph},
               {EX.WorkingGraph2, RDF.type(), DCATR.WorkingGraph},
               {EX.LocalSystemGraph, RDF.type(), DCATR.SystemGraph},
               {EX.ServiceData1, RDF.type(), DCATR.ServiceData},
               {EX.ServiceData1, DCATR.serviceManifestGraph(), EX.ServiceManifest},
               {EX.ServiceData1, DCATR.serviceWorkingGraph(),
                [EX.WorkingGraph1, EX.WorkingGraph2]},
               {EX.ServiceData1, DCATR.serviceSystemGraph(), EX.LocalSystemGraph},
               {EX.Service1, RDF.type(), DCATR.Service},
               {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
               {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
               {EX.WorkingGraph1, DCATR.localGraphName(), EX.WorkingGraph1Name},
               {EX.ServiceManifest, DCATR.localGraphName(), RDF.bnode("ServiceManifest")},
               {EX.DataGraph2, DCATR.localGraphName(), RDF.bnode(:graph2)},
               {EX.DataGraph1, RDF.type(), DCATR.DefaultGraph}
             ])
             |> Service.load(EX.Service1, depth: 99) == {:ok, example_service()}
    end
  end

  test "Grax.to_rdf/1" do
    repository = repository()
    manifest = service_manifest_graph()
    local_data = service_data(manifest_graph: manifest)
    service = service(repository: repository, local_data: local_data)

    rdf = Grax.to_rdf!(service)

    assert RDF.Graph.include?(rdf, {service.__id__, RDF.type(), DCATR.Service})
    assert RDF.Graph.include?(rdf, {service.__id__, DCATR.serviceRepository(), repository.__id__})
    assert RDF.Graph.include?(rdf, {service.__id__, DCATR.serviceLocalData(), local_data.__id__})
    assert RDF.Graph.include?(rdf, {local_data.__id__, RDF.type(), DCATR.ServiceData})

    assert RDF.Graph.include?(
             rdf,
             {local_data.__id__, DCATR.serviceManifestGraph(), manifest.__id__}
           )
  end

  describe "graph/2" do
    setup :example_service_scenario

    test "finds graph by local name", %{service: service, working_graphs: [graph1 | _]} do
      assert Service.graph(service, EX.WorkingGraph1Name) == graph1
    end

    test "finds graph by :default selector", %{service: service, data_graphs: [graph1 | _]} do
      assert Service.graph(service, :default) == graph1
    end

    test "finds graph by blank node local name", %{service: service, data_graphs: [_, graph2]} do
      assert Service.graph(service, RDF.bnode(:graph2)) == graph2
    end

    test "finds graph by selector :manifest", %{service: service, service_manifest: manifest} do
      assert Service.graph(service, :manifest) == manifest
    end

    test "finds working graph by direct ID", %{service: service, working_graphs: [graph | _]} do
      assert Service.graph(service, EX.WorkingGraph1) == graph
    end

    test "finds repository system graph by direct ID", %{
      service: service,
      system_graphs: [graph | _]
    } do
      assert Service.graph(service, EX.SystemGraph1) == graph
    end

    test "finds local system graph by direct ID", %{
      service: service,
      local_system_graphs: [local_system | _]
    } do
      assert Service.graph(service, EX.LocalSystemGraph) == local_system
    end

    test "finds graph by direct ID", %{service: service, data_graphs: [graph | _]} do
      assert Service.graph(service, EX.DataGraph1) == graph
    end

    test "returns nil for non-existent graph", %{service: service} do
      assert Service.graph(service, EX.NonExistent) == nil
    end
  end

  describe "graph_by_id/2" do
    setup :example_service_scenario

    test "finds graph from repository by ID", %{service: service, data_graphs: [graph | _]} do
      assert Service.graph_by_id(service, EX.DataGraph1) == graph
    end

    test "finds graph from local data by ID", %{service: service, service_manifest: manifest} do
      assert Service.graph_by_id(service, EX.ServiceManifest) == manifest
    end

    test "returns nil for non-existent ID", %{service: service} do
      assert Service.graph_by_id(service, EX.NonExistent) == nil
    end
  end

  describe "graph_by_name/2" do
    setup :example_service_scenario

    test "finds graph by URI local name", %{service: service, working_graphs: [graph | _]} do
      assert Service.graph_by_name(service, EX.WorkingGraph1Name) == graph
    end

    test "finds default graph by :default name", %{service: service, data_graphs: [graph | _]} do
      assert Service.graph_by_name(service, :default) == graph
    end

    test "finds graph by blank node local name", %{service: service, data_graphs: [_, graph2]} do
      assert Service.graph_by_name(service, RDF.bnode(:graph2)) == graph2
    end

    test "returns nil for non-existent name", %{service: service} do
      assert Service.graph_by_name(service, EX.NonExistent) == nil
      assert Service.graph_by_name(service(), :default) == nil
    end
  end

  describe "graphs/2" do
    setup :example_service_scenario

    test "returns all graphs by default", context do
      graphs = Service.graphs(context.service)

      assert context.service_manifest in graphs
      assert context.repo_manifest in graphs
      assert Enum.all?(context.data_graphs, &(&1 in graphs))
      assert Enum.all?(context.working_graphs, &(&1 in graphs))
      assert Enum.all?(context.system_graphs, &(&1 in graphs))
      assert Enum.all?(context.local_system_graphs, &(&1 in graphs))
    end

    test "filters by type option", %{service: service, working_graphs: working_graphs} do
      assert Service.graphs(service, type: :working) == working_graphs
    end
  end

  describe "has_graph?/2" do
    setup :example_service_scenario

    test "returns true for existing graph by ID", %{service: service} do
      assert Service.has_graph?(service, EX.DataGraph1)
    end

    test "returns true for existing graph by local name", %{service: service} do
      assert Service.has_graph?(service, EX.WorkingGraph1Name)
    end

    test "returns true for existing graph by :default name", %{service: service} do
      assert Service.has_graph?(service, :default)
    end

    test "returns false for non-existent graph", %{service: service} do
      assert Service.has_graph?(service, EX.NonExistent) == false
    end
  end

  describe "graph_name/2" do
    setup :example_service_scenario

    test "returns :default for graph with :default mapping", %{
      service: service,
      data_graphs: [graph | _]
    } do
      assert Service.graph_name(service, graph) == :default
    end

    test "returns graph name for graph ID", %{service: service} do
      assert Service.graph_name(service, EX.WorkingGraph1) == RDF.iri(EX.WorkingGraph1Name)
    end

    test "returns graph name for :manifest selector when manifest has local name", %{
      service: service
    } do
      assert Service.graph_name(service, :manifest) == RDF.bnode("ServiceManifest")
    end

    test "returns nil for graph without graph name", %{service: service} do
      assert Service.graph_name(service, EX.RepositoryManifest) == nil
    end

    test "returns nil for :manifest selector when no manifest exists" do
      service = service(local_data: empty_service_data())

      assert Service.graph_name(service, :manifest) == nil
    end
  end

  describe "graph_name_mapping/1" do
    setup :example_service_scenario

    test "returns complete name mapping", %{service: service} do
      mapping = Service.graph_name_mapping(service)

      assert is_map(mapping)
      assert Map.has_key?(mapping, :default)
      assert Map.has_key?(mapping, RDF.bnode(:graph2))
      assert Map.has_key?(mapping, RDF.iri(EX.WorkingGraph1Name))
    end
  end

  describe "add_graph_name/3" do
    setup :example_service_scenario

    test "adds a new graph name mapping", %{service: service, system_graphs: [graph | _]} do
      assert {:ok, updated} = Service.add_graph_name(service, EX.NewName, EX.SystemGraph1)

      assert updated.graph_names[RDF.iri(EX.NewName)] == RDF.iri(EX.SystemGraph1)
      assert updated.graph_names_by_id[RDF.iri(EX.SystemGraph1)] == RDF.iri(EX.NewName)
      assert Service.graph_by_name(updated, EX.NewName) == graph
    end

    test "adds :default mapping", %{service: service, data_graphs: [_, graph2]} do
      service = %{service | graph_names: %{}, graph_names_by_id: %{}}

      assert {:ok, updated} = Service.add_graph_name(service, :default, EX.DataGraph2)

      assert updated.graph_names[:default] == RDF.iri(EX.DataGraph2)
      assert updated.graph_names_by_id[RDF.iri(EX.DataGraph2)] == :default
      assert Service.default_graph(updated) == graph2
    end

    test "returns error for duplicate graph name", %{service: service} do
      assert Service.add_graph_name(service, EX.WorkingGraph1Name, EX.SystemGraph1) ==
               {:error, %DCATR.DuplicateGraphNameError{name: RDF.iri(EX.WorkingGraph1Name)}}
    end

    test "returns error for non-existent graph", %{service: service} do
      assert Service.add_graph_name(service, EX.NewName, EX.NonExistent) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistent)}}
    end

    test "blank node stability", %{service: service, data_graphs: [_, graph2]} do
      service = %{service | graph_names: %{}, graph_names_by_id: %{}}

      assert {:ok, updated} = Service.add_graph_name(service, RDF.bnode("test"), EX.DataGraph2)

      assert updated.graph_names[RDF.bnode("test")] == RDF.iri(EX.DataGraph2)
      assert Service.graph_by_name(updated, RDF.bnode("test")) == graph2
    end
  end

  describe "default_graph/1" do
    setup do
      service = example_service(with_graph_names: false)
      [data_graph1, data_graph2] = service.repository.dataset.graphs

      {:ok,
       %{
         service: service,
         data_graph1: data_graph1,
         data_graph2: data_graph2
       }}
    end

    test "returns the default graph when one is designated", context do
      manifest_rdf = RDF.graph({EX.DataGraph1, RDF.type(), DCATR.DefaultGraph})

      {:ok, service} = Service.on_load(context.service, manifest_rdf, [])

      assert Service.default_graph(service) == context.data_graph1
    end

    test "returns nil when no default graph is designated", %{service: service} do
      {:ok, service} = Service.on_load(service, RDF.graph(), [])
      assert Service.default_graph(service) == nil
    end

    test "raises error when multiple default graphs are designated", context do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, RDF.type(), DCATR.DefaultGraph})
        |> RDF.Graph.add({EX.DataGraph2, RDF.type(), DCATR.DefaultGraph})

      assert {:error, %DCATR.DuplicateGraphNameError{name: :default}} =
               Service.on_load(context.service, manifest_rdf, [])
    end
  end

  describe "on_load/3" do
    setup do
      {:ok, %{service: example_service(with_graph_names: false)}}
    end

    test "loads graph name mappings", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, DCATR.localGraphName(), EX.main()})
        |> RDF.Graph.add({EX.DataGraph2, DCATR.localGraphName(), RDF.bnode(:secondary)})

      assert {:ok, loaded} = Service.on_load(service, manifest_rdf, [])

      assert loaded.graph_names[RDF.iri(EX.main())] == RDF.iri(EX.DataGraph1)
      assert loaded.graph_names[RDF.bnode(:secondary)] == RDF.iri(EX.DataGraph2)

      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph1)] == RDF.iri(EX.main())
      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph2)] == RDF.bnode(:secondary)
    end

    test "loads default graph designation", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, RDF.type(), DCATR.DefaultGraph})

      assert {:ok, loaded} = Service.on_load(service, manifest_rdf, [])
      assert loaded.graph_names[:default] == RDF.iri(EX.DataGraph1)
      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph1)] == :default
    end

    test "returns error for duplicate local names", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, DCATR.localGraphName(), EX.main()})
        |> RDF.Graph.add({EX.DataGraph2, DCATR.localGraphName(), EX.main()})

      assert Service.on_load(service, manifest_rdf, []) ==
               {:error, %DCATR.DuplicateGraphNameError{name: EX.main()}}
    end

    test "returns error for non-existent graph ID in local name mapping", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.NonExistentGraph, DCATR.localGraphName(), EX.main()})

      assert Service.on_load(service, manifest_rdf, []) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistentGraph)}}
    end

    test "returns error for non-existent default graph", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.NonExistentGraph, RDF.type(), DCATR.DefaultGraph})

      assert Service.on_load(service, manifest_rdf, []) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistentGraph)}}
    end
  end
end
