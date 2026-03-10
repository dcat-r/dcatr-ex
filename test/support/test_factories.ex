defmodule DCATR.TestFactories do
  @moduledoc """
  Test factories for DCAT-R test suite.

  These factories are convenience wrappers around the schema `new/2` functions,
  providing sensible defaults for required and commonly used fields. They delegate
  all complexity to the actual schema modules and simply make test setup more concise.

  ## Factory Levels

  ### Basic Factories

  Basic factories wrap schema `new/2` functions with minimal defaults:

  - `data_graph/1`, `system_graph/1`, etc. - Simple graph factories
  - `dataset/1` - Wraps `Dataset.new/2`, provides defaults for `dataset`
  - `repository/1` - Wraps `Repository.new/2`, provides defaults for `dataset` and `manifest_graph`
  - `service_data/1` - Wraps `ServiceData.new/2`, provides default for `manifest_graph`
  - `service/1` - Wraps `Service.new/2`, provides defaults for `repository` and `local_data`

  Basic factories generate prefixed random IDs by default which can be overridden via the `:id` option.

  ### Example Factories

  Example factories provide fixed IDs for test scenarios where specific named resources are needed:

  - `example_data_graph/1` - Returns a data graph with ID `EX.DataGraph1`
  - `example_data_graphs/1` - Returns n data graphs with IDs `EX.DataGraph1`, `EX.DataGraph2`, etc.
  - `example_repository/1` - Returns a complete repository with fixed IDs for all components
  - `example_service_data/1` - Returns service data with fixed IDs
  - `example_service/1` - Returns a complete service with fixed IDs

  ### Scenario Functions

  Scenario functions are designed for use with ExUnit's `setup :function_name` syntax.
  They accept a context map and return an updated context with all test fixtures:

  - `example_dataset_scenario/1` - Returns `%{dataset: ..., data_graphs: [...]}`
  - `example_repository_scenario/1` - Returns `%{repo: ..., dataset: ..., data_graphs: [...], repo_manifest: ..., system_graphs: [...]}`
  - `example_service_data_scenario/1` - Returns `%{service_data: ..., service_manifest: ..., working_graphs: [...], local_system_graphs: [...]}`
  - `example_service_scenario/1` - Merges repository and service_data scenarios, adds `service:`

  Scenario functions build hierarchically, with higher-level scenarios calling lower-level ones.

  ## Integer Pattern for Lists

  Factory functions that accept list options (`:graphs`, `:system_graphs`,
  `:working_graphs`) support a convenient integer shorthand: passing an integer `n`
  will automatically generate `n` instances using the appropriate factory function.

  For example:

  - `dataset(graphs: 3)` creates a dataset with 3 auto-generated data graphs
  - `repository(system_graphs: 2)` creates a repository with 2 auto-generated system graphs

  ## Adding New Factories

  When adding a new schema (e.g., `NewGraph`):

  1. **Basic Factory**: Add `new_graph/1` wrapping `NewGraph.new/2` with defaults
  2. **Example Factory**: Add `example_new_graph/1` with fixed ID (e.g., `EX.NewGraph1`)
  3. **Example Plural**: If multiple instances make sense, add `example_new_graphs/1`
  4. **Scenario Update**: If the new schema is part of a hierarchy, update parent scenario functions
     to include it in the returned context map

  """

  use RDF
  import RDF, only: [bnode: 0]

  alias DCATR.{
    Repository,
    Dataset,
    Directory,
    Service,
    ServiceData,
    DataGraph,
    SystemGraph,
    RepositoryManifestGraph,
    ServiceManifestGraph,
    WorkingGraph,
    Manifest
  }

  alias DCATR.Case.EX
  @compile {:no_warn_undefined, DCATR.Case.EX}

  ###########################################################################
  # DataGraph

  def data_graph(opts \\ []) do
    id = Keyword.get(opts, :id, generate_id("DataGraph"))
    DataGraph.new!(id)
  end

  def example_data_graph(opts \\ []) do
    id = Keyword.get(opts, :id, EX.DataGraph1)
    data_graph(id: id)
  end

  def example_data_graphs(n \\ 2) do
    for i <- 1..n do
      data_graph(id: apply(EX, String.to_atom("DataGraph#{i}"), []))
    end
  end

  ###########################################################################
  # SystemGraph

  def system_graph(opts \\ []) do
    id = Keyword.get(opts, :id, generate_id("SystemGraph"))
    SystemGraph.new!(id)
  end

  def example_system_graph(opts \\ []) do
    id = Keyword.get(opts, :id, EX.SystemGraph1)
    system_graph(id: id)
  end

  def example_system_graphs(n \\ 2) do
    for i <- 1..n do
      system_graph(id: apply(EX, String.to_atom("SystemGraph#{i}"), []))
    end
  end

  ###########################################################################
  # RepositoryManifestGraph

  def repository_manifest_graph(opts \\ []) do
    id = Keyword.get(opts, :id, generate_id("ManifestGraph"))
    RepositoryManifestGraph.new!(id)
  end

  def example_repository_manifest_graph(opts \\ []) do
    id = Keyword.get(opts, :id, EX.RepositoryManifest)
    repository_manifest_graph(id: id)
  end

  ###########################################################################
  # ServiceManifestGraph

  def service_manifest_graph(opts \\ []) do
    id = Keyword.get(opts, :id, bnode())
    ServiceManifestGraph.new!(id)
  end

  def example_service_manifest_graph(opts \\ []) do
    id = Keyword.get(opts, :id, ~B<ServiceManifest>)
    service_manifest_graph(id: id)
  end

  ###########################################################################
  # WorkingGraph

  def working_graph(opts \\ []) do
    id = Keyword.get(opts, :id, bnode())
    WorkingGraph.new!(id)
  end

  def example_working_graph(opts \\ []) do
    id = Keyword.get(opts, :id, RDF.bnode(:WorkingGraph1))
    working_graph(id: id)
  end

  def example_working_graphs(n \\ 2) do
    for i <- 1..n do
      working_graph(id: RDF.bnode(String.to_atom("WorkingGraph#{i}")))
    end
  end

  ###########################################################################
  # Directory

  def directory(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Directory"))

    opts = Keyword.replace_lazy(opts, :members, expand_list(&data_graph/0))

    case Directory.new(id, opts) do
      {:ok, dir} -> dir
      {:error, error} -> raise error
    end
  end

  def example_directory(opts \\ []) do
    id = Keyword.get(opts, :id, EX.Directory1)
    members = Keyword.get(opts, :members, example_data_graphs())
    directory(id: id, members: members)
  end

  ###########################################################################
  # Dataset

  def dataset(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Dataset"))

    opts =
      opts
      |> Keyword.replace_lazy(:graphs, expand_list(&data_graph/0))
      |> Keyword.replace_lazy(:directories, expand_list(&directory/0))

    case Dataset.new(id, opts) do
      {:ok, dataset} -> dataset
      {:error, error} -> raise error
    end
  end

  def example_dataset(opts \\ []) do
    id = Keyword.get(opts, :id, EX.Dataset1)
    graphs = Keyword.get(opts, :graphs, example_data_graphs())
    dataset(id: id, graphs: graphs)
  end

  def example_dataset_scenario(context \\ %{}) do
    context
    |> Map.put(:dataset, example_dataset())
    |> Map.put(:data_graphs, example_data_graphs())
  end

  ###########################################################################
  # Repository

  def repository(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Repository"))

    opts
    |> Keyword.put_new(:dataset, dataset())
    |> build_repository(id)
  end

  def example_repository(opts \\ []) do
    id = Keyword.get(opts, :id, EX.Repository1)
    ds = Keyword.get(opts, :dataset, example_dataset())
    manifest = Keyword.get(opts, :manifest_graph, example_repository_manifest_graph())
    system_graphs = Keyword.get(opts, :system_graphs, example_system_graphs())

    repository(
      id: id,
      dataset: ds,
      manifest_graph: manifest,
      system_graphs: system_graphs
    )
  end

  def example_repository_scenario(context \\ %{}) do
    example_repository = example_repository()

    context
    |> example_dataset_scenario()
    |> Map.put(:repo, example_repository)
    |> Map.put(:repo_manifest, example_repository.manifest_graph)
    |> Map.put(:system_graphs, example_repository.system_graphs)
  end

  def single_graph_repository(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Repository"))
    {data_graph, opts} = Keyword.pop(opts, :data_graph, data_graph())

    opts
    |> Keyword.put(:data_graph, data_graph)
    |> build_repository(id)
  end

  def multi_graph_with_primary_repository(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Repository"))
    {ds, opts} = Keyword.pop(opts, :dataset, dataset(graphs: 3))
    {primary_graph, opts} = Keyword.pop(opts, :primary_graph)

    primary_graph = primary_graph || List.first(ds.graphs)

    opts
    |> Keyword.put(:dataset, ds)
    |> Keyword.put(:primary_graph, primary_graph)
    |> build_repository(id)
  end

  defp build_repository(opts, id) do
    opts
    |> Keyword.put_new(:manifest_graph, repository_manifest_graph())
    |> Keyword.replace_lazy(:system_graphs, expand_list(&system_graph/0))
    |> then(fn opts ->
      case Repository.new(id, opts) do
        {:ok, repo} -> repo
        {:error, error} -> raise error
      end
    end)
  end

  ###########################################################################
  # ServiceData

  def service_data(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, bnode())

    opts
    |> Keyword.put_new(:manifest_graph, service_manifest_graph())
    |> Keyword.replace_lazy(:working_graphs, expand_list(&working_graph/0))
    |> Keyword.replace_lazy(:system_graphs, expand_list(&system_graph/0))
    |> then(fn opts ->
      case ServiceData.new(id, opts) do
        {:ok, data} -> data
        {:error, error} -> raise error
      end
    end)
  end

  def example_service_data(opts \\ []) do
    id = Keyword.get(opts, :id, EX.ServiceData1)
    manifest = Keyword.get(opts, :manifest_graph, example_service_manifest_graph())
    working_graphs = Keyword.get(opts, :working_graphs, example_working_graphs())
    system_graphs = Keyword.get(opts, :system_graphs, [system_graph(id: EX.LocalSystemGraph)])

    service_data(
      id: id,
      manifest_graph: manifest,
      working_graphs: working_graphs,
      system_graphs: system_graphs
    )
  end

  def example_service_data_scenario(context \\ %{}) do
    example_service_data = example_service_data()

    context
    |> Map.put(:service_data, example_service_data)
    |> Map.put(:service_manifest, example_service_data.manifest_graph)
    |> Map.put(:working_graphs, example_service_data.working_graphs)
    |> Map.put(:local_system_graphs, example_service_data.system_graphs)
  end

  ###########################################################################
  # Service

  def service(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, generate_id("Service"))

    opts
    |> Keyword.put_new(:repository, repository())
    |> Keyword.put_new(:local_data, service_data())
    |> process_graph_name_mappings()
    |> then(fn opts ->
      case Service.new(id, opts) do
        {:ok, service} -> service
        {:error, error} -> raise error
      end
    end)
  end

  def example_service(opts \\ []) do
    id = Keyword.get(opts, :id, EX.Service1)
    repo = Keyword.get(opts, :repository, example_repository())
    local_data = Keyword.get(opts, :local_data, example_service_data())

    service(
      id: id,
      repository: repo,
      local_data: local_data,
      graph_name_mappings: graph_name_mapping(Keyword.get(opts, :with_graph_names, true))
    )
  end

  def example_service_scenario(context \\ %{}) do
    context
    |> example_repository_scenario()
    |> example_service_data_scenario()
    |> Map.put(:service, example_service())
  end

  ###########################################################################
  # Manifest

  def manifest(opts \\ []) do
    {id, opts} = Keyword.pop(opts, :id, RDF.iri(EX.Manifest))
    {validate?, opts} = Keyword.pop(opts, :validate, true)
    service = Keyword.get(opts, :service, service())
    dataset = Keyword.get_lazy(opts, :dataset, fn -> manifest_dataset(service) end)

    opts
    |> Keyword.put(:service, service)
    |> Keyword.put(:dataset, dataset)
    |> Keyword.put_new(:load_path, "/test")
    |> then(&Manifest.build!(id, &1))
    |> then(fn manifest ->
      if validate?, do: Grax.validate!(manifest), else: manifest
    end)
  end

  def partial_manifest(opts \\ []) do
    opts
    |> Keyword.put(:validate, false)
    |> manifest()
  end

  def example_manifest() do
    manifest(service: example_service())
  end

  def example_manifest_scenario(context \\ %{}) do
    context
    |> example_service_scenario()
    |> Map.put(:manifest, example_manifest())
  end

  def manifest_dataset(service) do
    service_graph =
      [
        service.__id__
        |> RDF.type(RDF.iri(service.__class__()))
        |> DCATR.serviceRepository(service.repository.__id_)
        |> DCATR.serviceLocalData(service.local_data.__id_),
        service.local_data.__id__
        |> DCATR.serviceManifestGraph(service.local_data.manifest_graph.__id__)
      ]
      |> RDF.Graph.new(name: RDF.bnode("service-manifest"))

    repo_graph =
      service.repository.__id__
      |> RDF.type(RDF.iri(service.repository.__class__()))
      |> DCATR.repositoryDataset(service.repository.dataset.__id__)
      |> DCATR.repositoryManifestGraph(service.repository.manifest_graph.__id__)
      |> RDF.Graph.new(name: RDF.bnode("repository-manifest"))

    RDF.Dataset.new([service_graph, repo_graph])
  end

  ###########################################################################
  # Helper functions

  defp expand_list(factory_fun) do
    fn
      n when is_integer(n) -> for _ <- 1..n, do: factory_fun.()
      value -> value
    end
  end

  defp generate_id(prefix) do
    counter = :erlang.unique_integer([:positive])
    apply(EX, String.to_atom("#{prefix}#{counter}"), [])
  end

  defp process_graph_name_mappings(opts) do
    case Keyword.pop(opts, :graph_name_mappings) do
      {nil, opts} ->
        opts

      {mapping, opts} when is_map(mapping) ->
        mappings = graph_name_mappings(mapping)

        opts
        |> Keyword.put(:graph_names, mappings.graph_names)
        |> Keyword.put(:graph_names_by_id, mappings.graph_names_by_id)
    end
  end

  def graph_name_mappings(mapping) when is_map(mapping) do
    {names, ids} =
      Enum.reduce(mapping, {%{}, %{}}, fn
        {graph_id, :default}, {names_acc, ids_acc} ->
          graph_id = RDF.coerce_graph_name(graph_id)
          {Map.put(names_acc, :default, graph_id), Map.put(ids_acc, graph_id, :default)}

        {graph_id, local_name}, {names_acc, ids_acc} ->
          graph_id = RDF.coerce_graph_name(graph_id)
          local_name = RDF.coerce_graph_name(local_name)

          {Map.put(names_acc, local_name, graph_id), Map.put(ids_acc, graph_id, local_name)}
      end)

    %{graph_names: names, graph_names_by_id: ids}
  end

  def graph_name_mapping(true) do
    %{
      EX.DataGraph1 => :default,
      EX.DataGraph2 => ~B<graph2>,
      ~B<WorkingGraph1> => EX.WorkingGraph1Name,
      ~B<ServiceManifest> => ~B<ServiceManifest>
    }
  end

  def graph_name_mapping(_), do: %{}
end
