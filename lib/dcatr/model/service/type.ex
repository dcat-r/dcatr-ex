defmodule DCATR.Service.Type do
  @moduledoc """
  Behaviour for service types that provide operations for repository access and processing.
  """
  alias DCATR.{Service, DuplicateGraphNameError}

  @type t :: module()
  @type schema :: Grax.Schema.t()
  @type coercible_graph_name :: Service.graph_name() | RDF.IRI.coercible()

  @doc """
  Loads a service from a dataset.

  This callback enables service initialization from RDF manifest data, supporting
  environment-specific configuration and manifest-based bootstrapping.

  Called by `DCATR.Manifest.Loader.load_manifest/2` during manifest loading to
  construct the complete service hierarchy (Service → Repository → Dataset).

  Override to customize service loading logic (e.g., loading additional linked resources,
  applying environment-specific transformations).
  """
  @callback load_from_dataset(
              dataset :: RDF.Dataset.t(),
              service_id :: RDF.IRI.coercible(),
              opts :: keyword()
            ) :: {:ok, schema()} | {:error, any()}

  @doc """
  Returns the graph name for a given graph, selector, or ID.

  This callback provides the critical graph-name translation API for triple-store access
  (e.g., Gno), where operations require the local graph name under which a graph is stored.

  Called by client code that needs to translate graph references into their local storage
  names for triple-store operations, SPARQL queries, or graph management commands.

  Override to customize graph name resolution (e.g., dynamic name generation, store-specific
  naming conventions).

  ## Options

  - `:strict` - When `true` (default), verifies graph existence before returning the ID;
    when `false`, returns the ID without existence check
  """
  @callback graph_name(
              service :: schema(),
              selector_or_graph_or_id :: atom() | DCATR.Graph.t() | RDF.IRI.coercible(),
              opts :: keyword()
            ) :: Service.graph_name() | nil

  @doc """
  Returns a graph by its local name.

  This callback enables lookups via service-specific local names.

  Override to customize name resolution logic.
  """
  @callback graph_by_name(service :: schema(), DCATR.Service.Type.coercible_graph_name()) ::
              DCATR.Graph.t() | nil

  @doc """
  Returns the default graph if one is designated.

  Override to customize default graph selection.
  """
  @callback default_graph(service :: schema()) :: DCATR.Graph.t() | nil

  @doc """
  Returns the primary graph from the repository if one is designated.

  Override to customize primary graph selection.
  """
  @callback primary_graph(service :: schema()) :: DCATR.DataGraph.t() | nil

  @doc """
  Returns the effective value of `use_primary_as_default` for this service.

  Resolves the three-value semantics:

  - When set in manifest: returns the manifest value (`true`, `false`, or `nil`)
  - When not set in manifest: returns application config value (defaults to `nil`)

  Override to customize the resolution logic (e.g., different configuration source).
  """
  @callback use_primary_as_default(service :: schema()) :: boolean() | nil

  @doc """
  Loads graph name mappings from a service manifest graph.

  This callback extracts local graph name assignments from RDF manifest data, populating
  the service's `graph_names` mapping.

  Usually called by `c:load_from_dataset/3` after the service and repository are loaded.

  Override to customize graph name extraction (e.g., additional naming schemes, validation).
  """
  @callback load_graph_names(service :: schema(), graph :: RDF.Graph.t()) ::
              {:ok, schema()} | {:error, Exception.t()}

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.Service.Type
      use DCATR.GraphResolver
      use Grax.Schema

      @doc """
      Loads a service from a dataset.

      This implementation of `c:DCATR.Service.Type.load_from_dataset/3` delegates to
      `DCATR.Service.Type.load_from_dataset/4`.
      """
      @impl true
      def load_from_dataset(dataset, service_id, opts \\ []) do
        DCATR.Service.Type.load_from_dataset(__MODULE__, dataset, service_id, opts)
      end

      @doc """
      Loads graph name mappings from a service manifest graph.

      This implementation of `c:DCATR.Service.Type.load_graph_names/2` delegates to
      `DCATR.Service.Type.load_graph_names/2`.
      """
      @impl true
      def load_graph_names(service, graph) do
        DCATR.Service.Type.load_graph_names(service, graph)
      end

      @doc """
      Returns the graph name for a given graph, selector, or ID.

      This implementation of `c:DCATR.Service.Type.graph_name/3` delegates to
      `DCATR.Service.Type.graph_name/3`.
      """
      @impl true
      def graph_name(service, selector_or_graph_or_id, opts \\ []) do
        DCATR.Service.Type.graph_name(service, selector_or_graph_or_id, opts)
      end

      @doc """
      Returns a graph by its local name.

      This implementation of `c:DCATR.Service.Type.graph_by_name/2` delegates to
      `DCATR.Service.Type.graph_by_name/2`.
      """
      @impl true
      def graph_by_name(service, name) do
        DCATR.Service.Type.graph_by_name(service, name)
      end

      @doc """
      Returns a graph by its ID.

      Delegates to `DCATR.Service.Type.graph_by_id/2`.
      """
      def graph_by_id(service, id) do
        DCATR.Service.Type.graph_by_id(service, id)
      end

      @doc """
      Resolves a symbolic selector to a graph.

      This implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2` delegates to
      `DCATR.Service.Type.resolve_graph_selector/2`.
      """
      @impl DCATR.GraphResolver
      def resolve_graph_selector(service, selector) do
        DCATR.Service.Type.resolve_graph_selector(service, selector)
      end

      @doc """
      Returns a graph by ID, local name, or symbolic selector.

      This overrides `DCATR.GraphResolver`'s generated `graph/2` to add local name lookup.

      Delegates to `DCATR.Service.Type.graph/2`.
      """
      def graph(service, selector_or_id) do
        DCATR.Service.Type.graph(service, selector_or_id)
      end

      @doc """
      Returns all graphs aggregated from repository and local_data catalogs.

      Delegates to `DCATR.Service.Type.graphs/1`.
      """
      def graphs(service) do
        DCATR.Service.Type.graphs(service)
      end

      @doc """
      Returns the default graph if one is designated.

      This implementation of `c:DCATR.Service.Type.default_graph/1` delegates to
      `DCATR.Service.Type.default_graph/1`.
      """
      @impl true
      def default_graph(service) do
        DCATR.Service.Type.default_graph(service)
      end

      @doc """
      Returns the primary graph from the repository if one is designated.

      This implementation of `c:DCATR.Service.Type.primary_graph/1` delegates to
      `DCATR.Service.Type.primary_graph/1`.
      """
      @impl true
      def primary_graph(service) do
        DCATR.Service.Type.primary_graph(service)
      end

      @doc """
      Returns the effective value of `use_primary_as_default` for this service.

      This implementation of `c:DCATR.Service.Type.use_primary_as_default/1` delegates to
      `DCATR.Service.Type.use_primary_as_default/1`.
      """
      @impl true
      def use_primary_as_default(service) do
        DCATR.Service.Type.use_primary_as_default(service)
      end

      @doc """
      Returns the complete local name to graph ID mapping.

      Delegates to `DCATR.Service.Type.graph_name_mapping/1`.
      """
      def graph_name_mapping(service) do
        DCATR.Service.Type.graph_name_mapping(service)
      end

      @doc """
      Returns the repository type module for this service type.
      """
      def repository_type do
        unquote(__MODULE__).repository_type(__MODULE__)
      end

      @doc """
      Returns the service data type module for this service type.
      """
      def service_data_type do
        unquote(__MODULE__).service_data_type(__MODULE__)
      end

      defoverridable load_from_dataset: 2,
                     load_from_dataset: 3,
                     load_graph_names: 2,
                     graph_name: 2,
                     graph_name: 3,
                     graph_by_name: 2,
                     graph_by_id: 2,
                     resolve_graph_selector: 2,
                     default_graph: 1,
                     primary_graph: 1,
                     use_primary_as_default: 1,
                     graph_name_mapping: 1
    end
  end

  # Public default implementations (called by __using__ delegation)

  alias DCATR.{Manifest, Catalog}

  import RDF.Guards

  @preloading_depth 10

  @doc """
  Default implementation of `c:load_from_dataset/3`.

  Loads service and repository from their manifest graphs in two stages from the 
  different manifest graphs, then enriches the service with graph name mappings 
  from the service manifest via `c:load_graph_names/2`.
  """
  @spec load_from_dataset(t(), RDF.Dataset.t(), RDF.IRI.coercible(), keyword()) ::
          {:ok, schema()} | {:error, any()}
  def load_from_dataset(service_type, dataset, service_id, opts \\ []) do
    with {:ok, service_graph} <- Manifest.service_manifest_graph(dataset),
         {:ok, repo_graph} <- Manifest.repository_manifest_graph(dataset),
         {:ok, service} <-
           service_type.load(
             service_graph,
             service_id,
             Keyword.put(opts, :depth, @preloading_depth)
           ),
         {:ok, service} <-
           Grax.preload(service, repository_preloading_graph(service, repo_graph),
             properties: :repository,
             depth: @preloading_depth
           ),
         {:ok, service} <- service_type.load_graph_names(service, service_graph) do
      {:ok, service}
    end
  end

  defp repository_preloading_graph(%service_type{} = service, graph) do
    RDF.Graph.add(
      graph,
      {service.__id__, repository_property_iri(service_type), extract_repository_id(service)}
    )
  end

  defp extract_repository_id(%_{repository: %RDF.IRI{} = repo_iri}), do: repo_iri
  defp extract_repository_id(%_{repository: %{__id__: repo_iri}}), do: repo_iri

  defp repository_property_iri(service_type) do
    case service_type.__property__(:repository) do
      %Grax.Schema.LinkProperty{iri: repository_property_iri} -> repository_property_iri
      invalid -> raise "Invalid repository property: #{inspect(invalid)}"
    end
  end

  @doc """
  Default implementation of `c:load_graph_names/2`.

  Extracts `dcatr:localGraphName` statements and `dcatr:DefaultGraph` type assertions
  from the given graph, populating `graph_names` and `graph_names_by_id` maps of `DCATR.Service`.

  After extracting explicit graph name mappings, applies automatic primary-as-default designation
  based on the service's `use_primary_as_default` setting.
  """
  @spec load_graph_names(schema(), RDF.Graph.t()) :: {:ok, schema()} | {:error, any()}
  def load_graph_names(service, graph) do
    with {:ok, service} <- extract_name_mappings(service, graph),
         {:ok, service} <- extract_default_graph(service, graph),
         {:ok, service} <- apply_primary_as_default(service) do
      {:ok, service}
    end
  end

  defp extract_name_mappings(service, graph) do
    graph
    |> RDF.Graph.query({:graph_id?, DCATR.localGraphName(), :graph_name?})
    |> Enum.reduce_while({:ok, service}, fn
      %{graph_id: graph_id, graph_name: graph_name}, {:ok, acc_service} ->
        case add_graph_name(acc_service, graph_name, graph_id) do
          {:ok, updated_service} -> {:cont, {:ok, updated_service}}
          {:error, _} = error -> {:halt, error}
        end
    end)
  end

  defp extract_default_graph(service, graph) do
    case RDF.Graph.query(graph, {:default_graph?, RDF.type(), DCATR.DefaultGraph}) do
      [] ->
        {:ok, service}

      [%{default_graph: default_graph_id}] ->
        add_graph_name(service, :default, default_graph_id)

      multiple ->
        graphs = Enum.map(multiple, fn %{default_graph: id} -> id end)

        {:error,
         %DuplicateGraphNameError{name: :default, graphs: graphs, reason: :explicit_duplicates}}
    end
  end

  defp apply_primary_as_default(
         %service_type{repository: %repository_type{} = repository} = service
       ) do
    use_primary_as_default = service_type.use_primary_as_default(service)
    primary_graph = repository_type.primary_graph(repository)
    primary_graph_id = primary_graph && primary_graph.__id__
    primary_name = primary_graph_id && Map.get(service.graph_names_by_id, primary_graph_id)
    explicit_default_id = Map.get(service.graph_names, :default)

    case {use_primary_as_default, primary_graph_id, primary_name, explicit_default_id} do
      # No primary graph - nothing to do
      {_, nil, _, _} ->
        {:ok, service}

      # false (disable) mode - no automatic designation
      {false, _, _, _} ->
        {:ok, service}

      # Primary already designated as :default - nothing to do
      {_, _, :default, _} ->
        {:ok, service}

      # nil (auto) mode: primary has explicit local name - don't override with :default
      {nil, _primary_id, name, _default_id} when not is_nil(name) ->
        {:ok, service}

      # nil (auto) mode: primary has no name, but explicit default exists - explicit takes precedence
      {nil, _primary_id, nil, default_id} when not is_nil(default_id) ->
        {:ok, service}

      # nil (auto) mode: primary has no name, no explicit default - designate as default
      {nil, primary_id, nil, nil} ->
        add_graph_name(service, :default, primary_id)

      # true (enforce) mode: primary has non-default name - error
      {true, primary_id, name, _} when not is_nil(name) and name != :default ->
        {:error,
         %DuplicateGraphNameError{
           name: :default,
           graphs: [primary_id, name],
           reason: :use_primary_as_default_enforced
         }}

      # true (enforce) mode: primary has no name, explicit default differs - error
      {true, primary_id, nil, default_id} when not is_nil(default_id) and default_id != primary_id ->
        {:error,
         %DuplicateGraphNameError{
           name: :default,
           graphs: [primary_id, default_id],
           reason: :use_primary_as_default_enforced
         }}

      # true (enforce) mode: primary has no name, no conflicting default - designate as default
      {true, primary_id, nil, _} ->
        add_graph_name(service, :default, primary_id)
    end
  end

  @doc """
  Adds a graph name mapping to the service.

  Validates graph existence and ensures name uniqueness before updating both
  `graph_names` (name→ID) and `graph_names_by_id` (ID→name) mappings of `DCATR.Service`.
  """
  @spec add_graph_name(schema(), coercible_graph_name(), coercible_graph_name()) ::
          {:ok, schema()} | {:error, Exception.t()}
  def add_graph_name(%service_type{} = service, graph_name, graph_id) do
    graph_id = RDF.iri(graph_id)
    graph_name = if graph_name == :default, do: :default, else: RDF.coerce_graph_name(graph_name)

    cond do
      Map.has_key?(service.graph_names, graph_name) ->
        {:error, %DCATR.DuplicateGraphNameError{name: graph_name}}

      not service_type.has_graph?(service, graph_id) ->
        {:error, %DCATR.GraphNotFoundError{graph_id: graph_id}}

      true ->
        {:ok,
         %{
           service
           | graph_names: Map.put(service.graph_names, graph_name, graph_id),
             graph_names_by_id: Map.put(service.graph_names_by_id, graph_id, graph_name)
         }}
    end
  end

  @doc """
  Default implementation of `c:graph_name/3`.

  Resolves selectors via `graph/2` and looks up local name mappings in `graph_names_by_id`.
  Returns `nil` if the graph does not exist (when `strict: true`).

  ## Options

  - `:strict` - When `true` (default), checks graph existence before returning
    the ID as a fallback. When `false`, returns the provided graph ID directly
    without existence check.
  """
  @spec graph_name(
          schema(),
          Catalog.selector() | DCATR.Graph.t() | RDF.IRI.coercible(),
          keyword()
        ) ::
          Service.graph_name() | nil
  def graph_name(service, selector_or_graph_or_id, opts \\ [])

  def graph_name(%service_type{} = service, %{__id__: id}, opts),
    do: service_type.graph_name(service, id, opts)

  def graph_name(%service_type{graph_names_by_id: names_by_id} = service, graph_id, opts)
      when is_rdf_resource(graph_id) do
    names_by_id[graph_id] ||
      if Keyword.get(opts, :strict, true) do
        if service_type.has_graph?(service, graph_id), do: graph_id
      else
        graph_id
      end
  end

  def graph_name(%service_type{} = service, ns_term_or_selector, opts) do
    case service_type.resolve_graph_selector(service, ns_term_or_selector) do
      :undefined ->
        if graph_id = RDF.coerce_graph_name(ns_term_or_selector) do
          service_type.graph_name(service, graph_id, opts)
        else
          nil
        end

      # Known selector but graph not available
      nil ->
        nil

      graph ->
        service_type.graph_name(service, graph.__id__, opts)
    end
  end

  @doc """
  Default implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2`.

  Resolves `:default` selector at service level, then delegates to Repository and ServiceData catalogs.
  """
  @spec resolve_graph_selector(schema(), Catalog.selector()) ::
          DCATR.Graph.t() | nil | :undefined
  def resolve_graph_selector(%service_type{} = service, :default) do
    service_type.default_graph(service)
  end

  def resolve_graph_selector(
        %{
          repository: %repository_type{} = repository,
          local_data: %service_data_type{} = local_data
        },
        selector
      ) do
    case repository_type.resolve_graph_selector(repository, selector) do
      :undefined -> service_data_type.resolve_graph_selector(local_data, selector)
      result -> result
    end
  end

  @doc """
  Default implementation of `graph/2`.

  Tries selector resolution, then local name lookup, then ID lookup across Repository
  and ServiceData catalogs.
  """
  @spec graph(schema(), Catalog.id_or_selector()) :: DCATR.Graph.t() | nil
  def graph(%service_type{} = service, name_or_selector_or_id) do
    case service_type.resolve_graph_selector(service, name_or_selector_or_id) do
      :undefined ->
        service_type.graph_by_name(service, name_or_selector_or_id) ||
          service_type.graph_by_id(service, name_or_selector_or_id)

      result ->
        result
    end
  end

  @doc """
  Default implementation of `c:graph_by_name/2`.

  Looks up the graph ID in `graph_names` mapping, then delegates to `graph_by_id/2`.
  """
  @spec graph_by_name(schema(), coercible_graph_name()) :: DCATR.Graph.t() | nil
  def graph_by_name(%{graph_names: names} = service, :default) do
    if graph_id = Map.get(names, :default) do
      graph_by_id(service, graph_id)
    end
  end

  def graph_by_name(%{graph_names: names} = service, graph_name) do
    if graph_id = Map.get(names, RDF.coerce_graph_name(graph_name)) do
      graph_by_id(service, graph_id)
    end
  end

  @doc """
  Default implementation of `graph_by_id/2`.

  Searches in Repository and ServiceData catalogs.
  """
  @spec graph_by_id(schema(), RDF.IRI.coercible()) :: DCATR.Graph.t() | nil
  def graph_by_id(
        %{
          repository: %repository_type{} = repository,
          local_data: %service_data_type{} = local_data
        },
        id
      ) do
    graph_id = RDF.coerce_graph_name(id)

    repository_type.graph(repository, graph_id) ||
      service_data_type.graph(local_data, graph_id)
  end

  @doc """
  Default implementation of `graphs/1`.

  Aggregates all graphs from Repository and ServiceData catalogs.
  """
  @spec graphs(schema()) :: [DCATR.Graph.t()]
  def graphs(%{
        repository: %repository_type{} = repository,
        local_data: %service_data_type{} = local_data
      }) do
    repository_type.all_graphs(repository) ++ service_data_type.all_graphs(local_data)
  end

  @doc """
  Default implementation of `c:default_graph/1`.

  Returns the graph mapped to the `:default` local name via `c:graph_by_name/2`.
  """
  @spec default_graph(schema()) :: DCATR.Graph.t() | nil
  def default_graph(%service_type{} = service) do
    service_type.graph_by_name(service, :default)
  end

  @doc """
  Default implementation of `c:primary_graph/1`.

  Delegates to the repository's `c:DCATR.Repository.Type.primary_graph/1`.
  """
  @spec primary_graph(schema()) :: DCATR.DataGraph.t() | nil
  def primary_graph(%{repository: %repository_type{} = repository}) do
    repository_type.primary_graph(repository)
  end

  @doc """
  Default implementation of `c:use_primary_as_default/1`.

  Resolves the three-value semantics:

  - When set in manifest: returns the manifest value (`true`, `false`, or `nil`)
  - When not set in manifest: returns application config value (defaults to `nil`), which can
    be configured like this

      config :dcatr, :use_primary_as_default, true # Enforce mode
  """
  @spec use_primary_as_default(schema()) :: boolean() | nil
  def use_primary_as_default(%{use_primary_as_default: nil}) do
    Application.get_env(:dcatr, :use_primary_as_default, nil)
  end

  def use_primary_as_default(%{use_primary_as_default: value}), do: value

  @doc """
  Default implementation for `graph_name_mapping/1`.

  Returns the `graph_names` map from the `DCATR.Service` struct.
  """
  @spec graph_name_mapping(schema()) :: Service.graph_names()
  def graph_name_mapping(%{graph_names: names}), do: names || %{}

  @doc """
  Returns the repository type module for a given service type.

  Extracts the `DCATR.Repository.Type` from the service's `:repository` property schema definition.

  ## Examples

      iex> DCATR.Service.Type.repository_type(DCATR.Service)
      DCATR.Repository
  """
  @spec repository_type(module()) :: module()
  def repository_type(service_type) do
    case service_type.__property__(:repository) do
      %Grax.Schema.LinkProperty{type: {:resource, repository_type_type}} -> repository_type_type
      invalid -> raise "Invalid repository type on service #{service_type}: #{inspect(invalid)}"
    end
  end

  @doc """
  Returns the service data type module for a given service type.

  Extracts the `DCATR.ServiceData.Type` from the service's `:local_data` property schema definition.

  ## Examples

      iex> DCATR.Service.Type.service_data_type(DCATR.Service)
      DCATR.ServiceData
  """
  @spec service_data_type(module()) :: module()
  def service_data_type(service_type) do
    case service_type.__property__(:local_data) do
      %Grax.Schema.LinkProperty{type: {:resource, service_data_type}} -> service_data_type
      invalid -> raise "Invalid service data type on service #{service_type}: #{inspect(invalid)}"
    end
  end
end
