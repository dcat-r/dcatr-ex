defmodule DCATR.ServiceTest do
  use DCATR.Case

  doctest DCATR.Service

  alias DCATR.Service

  test "new/1,2" do
    repository = repository()
    local_data = service_data()

    assert Service.new(EX.Service1,
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

  describe "use_primary_as_default/1" do
    test "returns manifest value when set to true" do
      {:ok, service} =
        Service.new(EX.Service1,
          repository: repository(),
          local_data: service_data(),
          use_primary_as_default: true
        )

      assert Service.use_primary_as_default(service) == true
    end

    test "returns manifest value when set to false" do
      {:ok, service} =
        Service.new(EX.Service1,
          repository: repository(),
          local_data: service_data(),
          use_primary_as_default: false
        )

      assert Service.use_primary_as_default(service) == false
    end

    test "returns application config value when not set in manifest" do
      with_application_env(:dcatr, :use_primary_as_default, true, fn ->
        {:ok, service} =
          Service.new(EX.Service1,
            repository: repository(),
            local_data: service_data()
          )

        assert Service.use_primary_as_default(service) == true
      end)

      with_application_env(:dcatr, :use_primary_as_default, false, fn ->
        {:ok, service} =
          Service.new(EX.Service1,
            repository: repository(),
            local_data: service_data()
          )

        assert Service.use_primary_as_default(service) == false
      end)
    end

    test "returns nil when neither manifest nor config set" do
      with_application_env(:dcatr, :use_primary_as_default, nil, fn ->
        {:ok, service} =
          Service.new(EX.Service1,
            repository: repository(),
            local_data: service_data()
          )

        assert Service.use_primary_as_default(service) == nil
      end)
    end
  end

  describe "load/2" do
    test "minimal service" do
      assert RDF.graph([
               {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
               {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
               {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
               {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
               {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>}
             ])
             |> Service.load(EX.Service1, depth: 99) ==
               {:ok,
                Service.new!(EX.Service1,
                  repository:
                    repository(
                      id: EX.Repository1,
                      dataset: dataset(id: EX.Dataset1),
                      manifest_graph: repository_manifest_graph(id: EX.RepositoryManifest)
                    ),
                  local_data:
                    service_data(
                      id: EX.ServiceData1,
                      manifest_graph: service_manifest_graph(id: ~B<ServiceManifest>)
                    )
                )}
    end

    @tag skip:
           "TODO: fix service graph metadata leak into graph schemas; for now load_from_dataset/3 should be used instead"
    test "service with all properties; not preloading repository" do
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
               {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
               {EX.Repository1, DCATR.repositorySystemGraph(),
                [EX.SystemGraph1, EX.SystemGraph2]},
               {~B<ServiceManifest>, RDF.type(), DCATR.ServiceManifestGraph},
               {~B<WorkingGraph1>, RDF.type(), DCATR.WorkingGraph},
               {~B<WorkingGraph2>, RDF.type(), DCATR.WorkingGraph},
               {EX.LocalSystemGraph, RDF.type(), DCATR.SystemGraph},
               {EX.ServiceData1, RDF.type(), DCATR.ServiceData},
               {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
               {EX.ServiceData1, DCATR.serviceWorkingGraph(),
                [~B<WorkingGraph1>, ~B<WorkingGraph2>]},
               {EX.ServiceData1, DCATR.serviceSystemGraph(), EX.LocalSystemGraph},
               {EX.Service1, RDF.type(), DCATR.Service},
               {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
               {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
               {~B<WorkingGraph1>, DCATR.localGraphName(), EX.WorkingGraph1Name},
               {~B<ServiceManifest>, DCATR.localGraphName(), ~B<ServiceManifest>},
               {EX.DataGraph2, DCATR.localGraphName(), RDF.bnode(:graph2)},
               {EX.DataGraph1, RDF.type(), DCATR.DefaultGraph}
             ])
             |> Service.load(EX.Service1) ==
               {:ok,
                %{
                  example_service()
                  | graph_names: %{},
                    graph_names_by_id: %{},
                    repository: RDF.iri(EX.Repository1)
                }}
    end
  end

  describe "load_from_dataset/3" do
    test "loads service and repository from separate graphs" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:ok, service} = Service.load_from_dataset(dataset, EX.Service1)

      assert service.__id__ == RDF.iri(EX.Service1)
      assert %DCATR.Repository{} = service.repository
      assert service.repository.__id__ == RDF.iri(EX.Repository1)
      assert service.repository.dataset.__id__ == RDF.iri(EX.Dataset1)
    end

    test "loads service with local graph name mappings" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
          # Local graph name mappings in ServiceManifestGraph
          {EX.DataGraph1, DCATR.localGraphName(), EX.LocalName1}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph1},
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:ok, service} = Service.load_from_dataset(dataset, EX.Service1)

      assert service.graph_names[RDF.iri(EX.LocalName1)] == RDF.iri(EX.DataGraph1)
      assert service.graph_names_by_id[RDF.iri(EX.DataGraph1)] == RDF.iri(EX.LocalName1)

      assert %DCATR.DataGraph{} = graph = Service.graph_by_name(service, EX.LocalName1)
      assert graph.__id__ == RDF.iri(EX.DataGraph1)
    end

    test "loads service with default graph designation" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
          # Default graph designation in ServiceManifestGraph
          {EX.DataGraph1, RDF.type(), DCATR.DefaultGraph}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph1},
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:ok, service} = Service.load_from_dataset(dataset, EX.Service1)

      assert service.graph_names[:default] == RDF.iri(EX.DataGraph1)
      assert service.graph_names_by_id[RDF.iri(EX.DataGraph1)] == :default

      assert %DCATR.DataGraph{} = graph = Service.default_graph(service)
      assert graph.__id__ == RDF.iri(EX.DataGraph1)
    end

    test "returns error when graph name references non-existent graph" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
          # Reference to non-existent graph
          {EX.NonExistentGraph, DCATR.localGraphName(), EX.LocalName1}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert Service.load_from_dataset(dataset, EX.Service1) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistentGraph)}}
    end

    test "returns error when multiple default graphs are designated" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
          # Multiple default graphs
          {EX.DataGraph1, RDF.type(), DCATR.DefaultGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DefaultGraph}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph1},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph2},
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DataGraph}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:error, %DCATR.DuplicateGraphNameError{name: :default}} =
               Service.load_from_dataset(dataset, EX.Service1)
    end

    test "returns error when service manifest graph is missing" do
      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:error, %DCATR.ManifestError{reason: :no_service_graph}} =
               Service.load_from_dataset(dataset, EX.Service1)
    end

    test "returns error when repository manifest graph is missing" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )

      assert {:error, %DCATR.ManifestError{reason: :no_repository_graph}} =
               Service.load_from_dataset(dataset, EX.Service1)
    end

    test "returns error when both manifest graphs are missing" do
      dataset = RDF.Dataset.new()

      assert {:error, %DCATR.ManifestError{reason: :no_service_graph}} =
               Service.load_from_dataset(dataset, EX.Service1)
    end

    test "loads service with local graph names from separate graphs" do
      service_graph =
        RDF.graph([
          {EX.Service1, RDF.type(), DCATR.Service},
          {EX.Service1, DCATR.serviceRepository(), EX.Repository1},
          {EX.Service1, DCATR.serviceLocalData(), EX.ServiceData1},
          {EX.ServiceData1, DCATR.serviceManifestGraph(), ~B<ServiceManifest>},
          # Local graph name mappings in ServiceManifestGraph
          {EX.DataGraph1, DCATR.localGraphName(), EX.LocalName1},
          {EX.DataGraph2, RDF.type(), DCATR.DefaultGraph}
        ])

      repo_graph =
        RDF.graph([
          {EX.Repository1, RDF.type(), DCATR.Repository},
          {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph1},
          {EX.Dataset1, DCATR.dataGraph(), EX.DataGraph2},
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DataGraph}
        ])

      dataset =
        RDF.Dataset.new()
        |> RDF.Dataset.add(service_graph,
          graph: DCATR.Manifest.Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add(repo_graph,
          graph: DCATR.Manifest.Loader.repository_manifest_graph_name()
        )

      assert {:ok, service} = Service.load_from_dataset(dataset, EX.Service1)

      assert service.graph_names[RDF.iri(EX.LocalName1)] == RDF.iri(EX.DataGraph1)
      assert service.graph_names[:default] == RDF.iri(EX.DataGraph2)
      assert service.graph_names_by_id[RDF.iri(EX.DataGraph1)] == RDF.iri(EX.LocalName1)
      assert service.graph_names_by_id[RDF.iri(EX.DataGraph2)] == :default

      assert %DCATR.DataGraph{__id__: graph1_id} = Service.graph_by_name(service, EX.LocalName1)
      assert graph1_id == RDF.iri(EX.DataGraph1)

      assert %DCATR.DataGraph{__id__: graph2_id} = Service.default_graph(service)
      assert graph2_id == RDF.iri(EX.DataGraph2)
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

    test "finds graph by manifest selectors", %{
      service: service,
      service_manifest: service_manifest,
      repo_manifest: repo_manifest
    } do
      assert Service.graph(service, :service_manifest) == service_manifest
      assert Service.graph(service, :repository_manifest) == repo_manifest
      assert Service.graph(service, :repo_manifest) == repo_manifest
    end

    test "finds graph by direct ID", %{
      service: service,
      data_graphs: [data_graph | _],
      working_graphs: [working_graph | _],
      system_graphs: [graph | _],
      local_system_graphs: [local_system | _]
    } do
      assert Service.graph(service, EX.DataGraph1) == data_graph
      assert Service.graph(service, RDF.bnode(:WorkingGraph1)) == working_graph
      assert Service.graph(service, RDF.iri(EX.SystemGraph1)) == graph
      assert Service.graph(service, EX.LocalSystemGraph) == local_system
    end

    test "returns nil for non-existent graph", %{service: service} do
      assert Service.graph(service, EX.NonExistent) == nil
    end

    test "returns primary graph via :primary selector" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data())

      assert Service.graph(service, :primary) == primary_graph
    end

    test "returns nil for :primary when repository has no primary_graph", %{service: service} do
      assert Service.graph(service, :primary) == nil
    end
  end

  describe "resolve_graph_selector/2" do
    test "resolves service and repository manifest selectors" do
      service = example_service()

      assert Service.resolve_graph_selector(service, :service_manifest) ==
               service.local_data.manifest_graph

      assert Service.resolve_graph_selector(service, :repository_manifest) ==
               service.repository.manifest_graph

      assert Service.resolve_graph_selector(service, :repo_manifest) ==
               service.repository.manifest_graph
    end

    test "resolves :primary when repository has primary_graph" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data())

      assert Service.resolve_graph_selector(service, :primary) == primary_graph
    end

    test "returns nil for :primary when repository has no primary_graph" do
      service = example_service()

      assert Service.resolve_graph_selector(service, :primary) == nil
    end

    test "resolves :default when default graph is designated" do
      service = example_service()

      assert Service.resolve_graph_selector(service, :default) ==
               List.first(service.repository.dataset.graphs)
    end

    test "returns nil for :default when no default graph is designated" do
      service = example_service(with_graph_names: false)

      assert Service.resolve_graph_selector(service, :default) == nil
    end

    test "returns :undefined for unknown selectors" do
      service = example_service()

      assert Service.resolve_graph_selector(service, :unknown_selector) == :undefined
    end
  end

  describe "graph_by_id/2" do
    setup :example_service_scenario

    test "finds graph from repository by ID", %{service: service, data_graphs: [graph | _]} do
      assert Service.graph_by_id(service, EX.DataGraph1) == graph
    end

    test "finds graph from local data by ID", %{service: service, service_manifest: manifest} do
      assert Service.graph_by_id(service, ~B<ServiceManifest>) == manifest
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

    test "returns true for :primary selector when repository has primary_graph" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data())

      assert Service.has_graph?(service, :primary) == true
    end

    test "returns false for :primary selector when repository has no primary_graph", %{
      service: service
    } do
      assert Service.has_graph?(service, :primary) == false
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
      assert Service.graph_name(service, EX.DataGraph2) == RDF.bnode(:graph2)

      assert Service.graph_name(service, RDF.bnode("WorkingGraph1")) ==
               RDF.iri(EX.WorkingGraph1Name)
    end

    test "returns graph name for manifest selectors", %{
      service: service
    } do
      # Service manifest has a local name
      assert Service.graph_name(service, :service_manifest) == ~B<ServiceManifest>
      # Repository manifest has no local name, falls back to graph ID
      assert Service.graph_name(service, :repository_manifest) == RDF.iri(EX.RepositoryManifest)
      assert Service.graph_name(service, :repo_manifest) == RDF.iri(EX.RepositoryManifest)
    end

    test "returns graph ID for graphs without local name mapping", %{service: service} do
      assert Service.graph_name(service, EX.RepositoryManifest) == RDF.iri(EX.RepositoryManifest)
      assert Service.graph_name(service, EX.SystemGraph1) == RDF.iri(EX.SystemGraph1)
    end

    test "returns nil for non-existent graph ID (default strict: true)", %{service: service} do
      assert Service.graph_name(service, EX.NonExistentGraph) == nil
    end

    test "returns :default for :default selector", %{service: service} do
      assert Service.graph_name(service, :default) == :default
    end
  end

  describe "graph_name/3 with :strict option" do
    setup :example_service_scenario

    test "strict: true returns nil for non-existent graph ID", %{service: service} do
      assert Service.graph_name(service, EX.NonExistentGraph, strict: true) == nil
    end

    test "strict: true returns graph ID for existing graphs", %{service: service} do
      assert Service.graph_name(service, EX.RepositoryManifest, strict: true) ==
               RDF.iri(EX.RepositoryManifest)

      assert Service.graph_name(service, EX.SystemGraph1, strict: true) ==
               RDF.iri(EX.SystemGraph1)
    end

    test "strict: false returns graph ID even for non-existent graphs", %{service: service} do
      assert Service.graph_name(service, EX.NonExistentGraph, strict: false) ==
               RDF.iri(EX.NonExistentGraph)
    end

    test "strict: false returns graph ID for existing graphs", %{service: service} do
      assert Service.graph_name(service, EX.RepositoryManifest, strict: false) ==
               RDF.iri(EX.RepositoryManifest)

      assert Service.graph_name(service, EX.SystemGraph1, strict: false) ==
               RDF.iri(EX.SystemGraph1)
    end

    test "strict: true still returns local name mappings when present", %{service: service} do
      assert Service.graph_name(service, EX.DataGraph2, strict: true) == RDF.bnode(:graph2)
    end

    test "strict: false still returns local name mappings when present", %{service: service} do
      assert Service.graph_name(service, EX.DataGraph2, strict: false) == RDF.bnode(:graph2)
    end

    test "handles nil", %{service: service} do
      assert Service.graph_name(service, nil) == nil
      assert Service.graph_name(service, nil, strict: false) == nil
      assert Service.graph_name(service, nil, strict: true) == nil
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

      {:ok, service} = Service.load_graph_names(context.service, manifest_rdf)

      assert Service.default_graph(service) == context.data_graph1
    end

    test "returns nil when no default graph is designated", %{service: service} do
      {:ok, service} = Service.load_graph_names(service, RDF.graph())
      assert Service.default_graph(service) == nil
    end

    test "raises error when multiple default graphs are designated", context do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, RDF.type(), DCATR.DefaultGraph})
        |> RDF.Graph.add({EX.DataGraph2, RDF.type(), DCATR.DefaultGraph})

      assert {:error, %DCATR.DuplicateGraphNameError{name: :default}} =
               Service.load_graph_names(context.service, manifest_rdf)
    end
  end

  describe "load_graph_names/2" do
    setup do
      {:ok, %{service: example_service(with_graph_names: false)}}
    end

    test "loads graph name mappings", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, DCATR.localGraphName(), EX.main()})
        |> RDF.Graph.add({EX.DataGraph2, DCATR.localGraphName(), RDF.bnode(:secondary)})

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)

      assert loaded.graph_names[RDF.iri(EX.main())] == RDF.iri(EX.DataGraph1)
      assert loaded.graph_names[RDF.bnode(:secondary)] == RDF.iri(EX.DataGraph2)

      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph1)] == RDF.iri(EX.main())
      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph2)] == RDF.bnode(:secondary)
    end

    test "loads default graph designation", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, RDF.type(), DCATR.DefaultGraph})

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == RDF.iri(EX.DataGraph1)
      assert loaded.graph_names_by_id[RDF.iri(EX.DataGraph1)] == :default
    end

    test "returns error for duplicate local names", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.DataGraph1, DCATR.localGraphName(), EX.main()})
        |> RDF.Graph.add({EX.DataGraph2, DCATR.localGraphName(), EX.main()})

      assert Service.load_graph_names(service, manifest_rdf) ==
               {:error, %DCATR.DuplicateGraphNameError{name: EX.main()}}
    end

    test "returns error for non-existent graph ID in local name mapping", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.NonExistentGraph, DCATR.localGraphName(), EX.main()})

      assert Service.load_graph_names(service, manifest_rdf) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistentGraph)}}
    end

    test "returns error for non-existent default graph", %{service: service} do
      manifest_rdf =
        RDF.graph()
        |> RDF.Graph.add({EX.NonExistentGraph, RDF.type(), DCATR.DefaultGraph})

      assert Service.load_graph_names(service, manifest_rdf) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistentGraph)}}
    end
  end

  describe "load_graph_names/2 with use_primary_as_default" do
    test "nil (auto) mode - primary becomes default when no explicit default" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data(), use_primary_as_default: nil)

      manifest_rdf = RDF.graph()

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == RDF.iri(EX.PrimaryGraph)
      assert loaded.graph_names_by_id[RDF.iri(EX.PrimaryGraph)] == :default
      assert Service.default_graph(loaded) == primary_graph
    end

    test "nil (auto) mode - explicit default overrides primary (no error)" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      explicit_default = data_graph(id: EX.ExplicitDefault)

      repo =
        repository(
          primary_graph: primary_graph,
          dataset: dataset(graphs: [primary_graph, explicit_default])
        )

      service = service(repository: repo, local_data: service_data(), use_primary_as_default: nil)

      manifest_rdf = RDF.graph({EX.ExplicitDefault, RDF.type(), DCATR.DefaultGraph})

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == RDF.iri(EX.ExplicitDefault)
      assert loaded.graph_names_by_id[RDF.iri(EX.ExplicitDefault)] == :default
      assert Service.default_graph(loaded) == explicit_default
    end

    test "nil (auto) mode - primary with explicit local name does NOT get :default" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data(), use_primary_as_default: nil)

      manifest_rdf = RDF.graph({EX.PrimaryGraph, DCATR.localGraphName(), EX.main()})

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[RDF.iri(EX.main())] == RDF.iri(EX.PrimaryGraph)
      assert loaded.graph_names[:default] == nil
      assert Service.default_graph(loaded) == nil
    end

    test "true (enforce) mode - primary becomes default" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)

      service =
        service(repository: repo, local_data: service_data(), use_primary_as_default: true)

      manifest_rdf = RDF.graph()

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == RDF.iri(EX.PrimaryGraph)
      assert Service.default_graph(loaded) == primary_graph
    end

    test "true (enforce) mode - error when primary has non-default local name" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)

      service =
        service(repository: repo, local_data: service_data(), use_primary_as_default: true)

      manifest_rdf = RDF.graph({EX.PrimaryGraph, DCATR.localGraphName(), EX.main()})

      assert Service.load_graph_names(service, manifest_rdf) ==
               {:error,
                %DCATR.DuplicateGraphNameError{
                  name: :default,
                  graphs: [RDF.iri(EX.PrimaryGraph), EX.main()],
                  reason: :use_primary_as_default_enforced
                }}
    end

    test "true (enforce) mode - error when explicit default differs from primary" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      other_graph = data_graph(id: EX.OtherGraph)

      repo =
        repository(
          primary_graph: primary_graph,
          dataset: dataset(graphs: [primary_graph, other_graph])
        )

      service =
        service(repository: repo, local_data: service_data(), use_primary_as_default: true)

      manifest_rdf = RDF.graph({EX.OtherGraph, RDF.type(), DCATR.DefaultGraph})

      assert Service.load_graph_names(service, manifest_rdf) ==
               {:error,
                %DCATR.DuplicateGraphNameError{
                  name: :default,
                  graphs: [RDF.iri(EX.PrimaryGraph), RDF.iri(EX.OtherGraph)],
                  reason: :use_primary_as_default_enforced
                }}
    end

    test "true (enforce) mode - success when explicit default matches primary" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)

      service =
        service(repository: repo, local_data: service_data(), use_primary_as_default: true)

      manifest_rdf = RDF.graph({EX.PrimaryGraph, RDF.type(), DCATR.DefaultGraph})

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == RDF.iri(EX.PrimaryGraph)
      assert Service.default_graph(loaded) == primary_graph
    end

    test "false (disable) mode - no automatic designation (default_graph remains nil)" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)

      service =
        service(repository: repo, local_data: service_data(), use_primary_as_default: false)

      manifest_rdf = RDF.graph()

      assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
      assert loaded.graph_names[:default] == nil
      assert Service.default_graph(loaded) == nil
    end

    test "no primary graph - all modes do nothing" do
      repo = repository(dataset: dataset(graphs: [data_graph(id: EX.SomeGraph)]))

      for mode <- [nil, true, false] do
        service =
          service(repository: repo, local_data: service_data(), use_primary_as_default: mode)

        manifest_rdf = RDF.graph()

        assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
        assert loaded.graph_names[:default] == nil
        assert Service.default_graph(loaded) == nil
      end
    end

    test "application config fallback when not set in manifest" do
      primary_graph = data_graph(id: EX.PrimaryGraph)
      repo = single_graph_repository(primary_graph: primary_graph)
      service = service(repository: repo, local_data: service_data())

      manifest_rdf = RDF.graph()

      with_application_env(:dcatr, :use_primary_as_default, nil, fn ->
        assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
        assert loaded.graph_names[:default] == RDF.iri(EX.PrimaryGraph)
      end)

      with_application_env(:dcatr, :use_primary_as_default, false, fn ->
        assert {:ok, loaded} = Service.load_graph_names(service, manifest_rdf)
        assert loaded.graph_names[:default] == nil
      end)
    end
  end
end
