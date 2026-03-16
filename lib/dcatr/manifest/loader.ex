defmodule DCATR.Manifest.Loader do
  @moduledoc """
  Loads the manifest from the configured load path.

  This module provides the default implementations of the `DCATR.Manifest.Type` callbacks.
  Custom manifest types can override any of these by implementing the corresponding callback.

  ## Loading Pipeline

  Manifest loading proceeds in two phases:

  1. **Dataset loading** (`load_dataset/1` → `load_file/2` per file → `graph_name_for_file/2`):
     Resolves files from the load path, reads each RDF file, classifies it into the appropriate
     manifest graph, and merges everything into a single `RDF.Dataset`.

  2. **Manifest building** (`load_manifest/2`):
     Finds the service resource in the dataset, auto-injects missing `dcatr:ServiceData` and
     `dcatr:ServiceManifestGraph` structures with default IDs when not explicitly declared,
     then loads the complete service hierarchy (Service → Repository → Dataset).

  ## Well-Known Blank Node Graph Names

  When manifest configuration is stored in separate Turtle files (rather than a single TriG file),
  each file is classified and placed into a named graph using well-known blank node labels:

  - `_:service-manifest` — for the service manifest graph
  - `_:repository-manifest` — for the repository manifest graph

  These conventions follow the DCAT-R specification and enable implementations to locate
  manifest graphs by convention without prior configuration.
  """

  alias DCATR.Manifest
  alias DCATR.Manifest.{LoadPath, GraphExpansion, LoadingError}
  alias DCATR.ManifestError

  @service_manifest_graph_name RDF.bnode("service-manifest")
  @repository_manifest_graph_name RDF.bnode("repository-manifest")

  @default_service_data_id RDF.bnode("service-data")
  @default_service_manifest_graph_id @service_manifest_graph_name

  @doc """
  Returns the configured default ID for the `DCATR.ServiceData` catalog.

  This is the auto-injected ID when a `DCATR.ServiceData` resource is not found in the manifest.

  By default, this is `#{@default_service_data_id}`, but can be configured with
  the `:default_service_data_id` option of the `:dcatr` application and should be a
  string with an IRI or a blank node ID starting with `_:`.

      config :dcatr, default_service_data_id: "_:service-data"

  """
  @spec default_service_data_id() :: RDF.Statement.graph_name()
  def default_service_data_id() do
    Application.get_env(:dcatr, :default_service_data_id, @default_service_data_id)
    |> RDF.coerce_graph_name()
  end

  @doc """
  Returns the configured default ID for the `DCATR.ServiceManifestGraph`.

  By default, this is `#{@default_service_manifest_graph_id}`, but can be configured with
  the `:default_service_manifest_graph_id` option of the `:dcatr` application and should be a
  string with an IRI or a blank node ID starting with `_:`.

      config :dcatr, default_service_manifest_graph_id: "_:service-manifest"
  """
  @spec default_service_manifest_graph_id() :: RDF.Statement.graph_name()
  def default_service_manifest_graph_id() do
    Application.get_env(
      :dcatr,
      :default_service_manifest_graph_id,
      @default_service_manifest_graph_id
    )
    |> RDF.coerce_graph_name()
  end

  @doc """
  Returns the well-known blank node name for the service manifest graph.

  This is the canonical name used during manifest loading to identify the
  service manifest graph in a dataset: `#{@service_manifest_graph_name}`.
  """
  @spec service_manifest_graph_name() :: RDF.BlankNode.t()
  def service_manifest_graph_name(), do: @service_manifest_graph_name

  @doc """
  Returns the well-known blank node name for the repository manifest graph.

  This is the canonical name used during manifest loading to identify the
  repository manifest graph in a dataset: `#{@repository_manifest_graph_name}`.
  """
  @spec repository_manifest_graph_name() :: RDF.BlankNode.t()
  def repository_manifest_graph_name(), do: @repository_manifest_graph_name

  @doc """
  Returns the configured base IRI for the manifest graph.

  Can be configured with the `:manifest_base` option of the `:dcatr` application:
    
      config :dcatr, manifest_base: "https://example.com/base/"

  ## Options

  - `:base` - Explicitly specify the base IRI (overrides application config)

  """
  @spec base(keyword()) :: String.t() | nil
  def base(opts \\ []) do
    Keyword.get(opts, :base, Application.get_env(:dcatr, :manifest_base))
  end

  @doc """
  Loads the manifest from the configured load path.

  Orchestrates the complete manifest loading pipeline:

  1. Resolves the load path
  2. Loads and merges RDF files into a dataset
  3. Builds the manifest structure
  4. Loads and validates the service

  ## Options

  - `:load_path` - Explicit load path (skips path resolution)
  - `:manifest_id` - ID for the manifest struct (defaults to Application config `:dcatr, :manifest_id` or a generated blank node)
  - `:service_id` - Explicit service ID (skips auto-detection)
  - `:env` - Environment for environment-specific configs
  - `:base` - Base IRI for relative URI resolution
  """
  @spec load(module(), keyword()) :: {:ok, struct()} | {:error, any()}
  def load(manifest_type, opts \\ []) do
    load_path = LoadPath.load_path(opts)

    opts =
      opts
      |> Keyword.put_new(:load_path, load_path)
      |> Keyword.put_new(:manifest_type, manifest_type)

    with {:ok, dataset} <- manifest_type.load_dataset(opts),
         {:ok, dataset} <- GraphExpansion.expand_dataset(dataset, opts) do
      manifest =
        dataset
        |> manifest_id(opts)
        |> manifest_type.build!(load_path: load_path, dataset: dataset)

      case manifest_type.load_manifest(manifest, opts) do
        {:ok, manifest} -> Grax.validate(manifest)
        {:error, %ManifestError{}} = error -> error
        {:error, error} -> {:error, ManifestError.exception(data: manifest, reason: error)}
      end
    end
  end

  defp manifest_id(_dataset, opts) do
    Keyword.get(opts, :manifest_id) ||
      Application.get_env(:dcatr, :manifest_id) ||
      RDF.bnode()
  end

  ###########################################################################
  # Default implementation of the `DCATR.Manifest.Type` callbacks.
  ###########################################################################

  @doc """
  Resolves files, loads them, and merges them into a dataset.

  Performs the following steps:

  1. Resolves files from load path (unless `opts[:files]` provided)
  2. Calls `init_dataset/1` to create the initial dataset
  3. Calls `load_file/2` for each file
  4. Merges results via `RDF.Dataset.put_properties/2`

  ## Options

  - `:manifest_type` - The manifest type module (required, set by `Type.__using__/1`)
  - `:files` - Explicit list of files to load (skips load path resolution)
  - `:load_path` - Load path for file resolution

  Default implementation of `c:DCATR.Manifest.Type.load_dataset/1`.
  """
  @spec load_dataset(opts :: keyword()) :: {:ok, RDF.Dataset.t()} | {:error, LoadingError.t()}
  def load_dataset(opts) do
    manifest_type = Keyword.fetch!(opts, :manifest_type)
    files = opts[:files] || LoadPath.files(opts)

    do_load_dataset(files, manifest_type, opts)
  end

  defp do_load_dataset([], _manifest_type, _opts) do
    {:error, LoadingError.exception(reason: :missing)}
  end

  defp do_load_dataset(files, manifest_type, opts) do
    Enum.reduce_while(files, manifest_type.init_dataset(opts), fn
      path, {:ok, acc} ->
        case manifest_type.load_file(path, opts) do
          {:ok, nil} ->
            {:cont, {:ok, acc}}

          {:ok, %RDF.Dataset{} = dataset} ->
            {:cont, {:ok, RDF.Dataset.put_properties(acc, dataset)}}

          {:ok, %RDF.Graph{} = graph} ->
            {:cont, {:ok, RDF.Dataset.put_properties(acc, graph)}}

          {:error, error} ->
            {:halt, {:error, LoadingError.exception(file: path, reason: error)}}
        end

      _, {:error, error} ->
        {:halt, {:error, LoadingError.exception(file: :init_dataset, reason: error)}}
    end)
  end

  @doc """
  Initializes an empty RDF dataset for manifest loading.

  Default implementation of `c:DCATR.Manifest.Type.init_dataset/1`.
  """
  @spec init_dataset(keyword()) :: {:ok, RDF.Dataset.t()} | {:error, any()}
  def init_dataset(_opts \\ []), do: {:ok, RDF.Dataset.new()}

  @doc """
  Reads an RDF file and classifies it into a named graph.

  Applies the base IRI from `base/1` if configured, then calls `graph_name_for_file/2`
  to determine the target graph name. Files classified as `:service_manifest` or
  `:repository_manifest` are placed into their well-known blank node graphs, others
  remain in the default graph.

  Default implementation of `c:DCATR.Manifest.Type.load_file/2`.
  """
  @spec load_file(Path.t(), keyword()) ::
          {:ok, RDF.Dataset.t() | RDF.Graph.t()} | {:error, any()}
  def load_file(file, opts) do
    manifest_type = Keyword.fetch!(opts, :manifest_type)

    with {:ok, data} <- RDF.read_file(file, base: base(opts)) do
      {:ok, classify_rdf_data(data, file, manifest_type, opts)}
    end
  end

  defp classify_rdf_data(%RDF.Dataset{} = dataset, _file, _manifest_type, _opts), do: dataset

  defp classify_rdf_data(%RDF.Graph{} = graph, file, manifest_type, opts) do
    graph_name = manifest_type.graph_name_for_file(file, opts)
    RDF.Graph.change_name(graph, graph_name)
  end

  @doc """
  Classifies a file and returns its target graph name.

  Uses `DCATR.Manifest.LoadPath.classify_file/1` to identify files as
  `:service_manifest`, `:repository_manifest`, or unclassified. Returns the
  corresponding well-known blank node for manifests, or `nil` for unclassified files.

  Default implementation of `c:DCATR.Manifest.Type.graph_name_for_file/2`.

  ## Example

      iex> DCATR.Manifest.Loader.graph_name_for_file("service.ttl")
      RDF.bnode("service-manifest")

      iex> DCATR.Manifest.Loader.graph_name_for_file("repository.ttl")
      RDF.bnode("repository-manifest")

      iex> DCATR.Manifest.Loader.graph_name_for_file("dataset.ttl")
      RDF.bnode("repository-manifest")

      iex> DCATR.Manifest.Loader.graph_name_for_file("other.ttl")
      nil

  """
  @spec graph_name_for_file(Path.t(), keyword()) :: RDF.Statement.graph_name() | nil
  def graph_name_for_file(file, _opts \\ []) do
    case LoadPath.classify_file(file) do
      :service_manifest -> @service_manifest_graph_name
      :repository_manifest -> @repository_manifest_graph_name
      nil -> nil
    end
  end

  @doc """
  Extracts and loads the service from the dataset, populating the manifest struct.

  Performs the following steps:

  1. Finds the service resource ID (via `:service_id` option or RDF.type() query)
  2. Auto-injects missing `dcatr:ServiceData` and `dcatr:ServiceManifestGraph` structures with default IDs
  3. Loads the complete service hierarchy via `load_service/3`

  Default implementation of `c:DCATR.Manifest.Type.load_manifest/2`.
  """
  @spec load_manifest(Manifest.Type.schema(), keyword()) ::
          {:ok, Manifest.Type.schema()} | {:error, ManifestError.t()}
  def load_manifest(
        %manifest_type{__id__: _, dataset: dataset, load_path: _, service: _} = manifest,
        opts \\ []
      ) do
    service_type = manifest_type.service_type()

    with {:ok, service_id} <- find_service_id(service_type, dataset, opts),
         {:ok, dataset} <- inject_service_structure(dataset, service_id),
         {:ok, service} <- service_type.load_from_dataset(dataset, service_id, opts) do
      {:ok,
       manifest
       |> Grax.put!(:service, service)
       |> Grax.put!(:dataset, dataset)}
    end
  end

  defp find_service_id(service_type, dataset, opts) do
    if service_id = Keyword.get(opts, :service_id) do
      {:ok, service_id}
    else
      service_id_from_dataset(service_type, dataset)
    end
  end

  defp service_id_from_dataset(service_type, %RDF.Dataset{} = dataset) do
    with {:ok, service_graph} <- service_graph(dataset) do
      service_id_from_dataset(service_type, service_graph)
    end
  end

  defp service_id_from_dataset(service_type, %RDF.Graph{} = graph) do
    case RDF.Graph.query(graph, {:service?, RDF.type(), RDF.iri(service_type.__class__())}) do
      [%{service: service}] -> {:ok, service}
      [] -> {:error, ManifestError.exception(data: graph, reason: :no_service)}
      multi -> {:error, ManifestError.exception(data: multi, reason: :multiple_services)}
    end
  end

  defp inject_service_structure(dataset, service_id) do
    with {:ok, service_graph} <- service_graph(dataset),
         {:ok, service_graph, service_data_id} <- inject_service_data(service_graph, service_id),
         {:ok, service_graph} <- inject_service_manifest_graph(service_graph, service_data_id) do
      {:ok, RDF.Dataset.put_graph(dataset, service_graph, graph: @service_manifest_graph_name)}
    end
  end

  defp inject_service_data(graph, service_id) do
    case RDF.Graph.query(graph, {service_id, DCATR.serviceLocalData(), :service_data_id?}) do
      [] ->
        default_service_data_id = default_service_data_id()

        {:ok,
         RDF.Graph.add(graph, {service_id, DCATR.serviceLocalData(), default_service_data_id}),
         default_service_data_id}

      [%{service_data_id: service_data_id}] ->
        {:ok, graph, service_data_id}

      multiple ->
        {:error,
         ManifestError.exception(
           data: Enum.map(multiple, & &1.service_data_id),
           reason: :multiple_service_data
         )}
    end
  end

  defp inject_service_manifest_graph(graph, service_data_id) do
    case RDF.Graph.query(
           graph,
           {service_data_id, DCATR.serviceManifestGraph(), :service_manifest_graph_id?}
         ) do
      [] ->
        {:ok,
         RDF.Graph.add(
           graph,
           {service_data_id, DCATR.serviceManifestGraph(), default_service_manifest_graph_id()}
         )}

      [%{service_manifest_graph_id: _service_manifest_graph_id}] ->
        {:ok, graph}

      multiple ->
        {:error,
         ManifestError.exception(
           data: Enum.map(multiple, & &1.service_manifest_graph_id),
           reason: :multiple_service_manifest_graphs
         )}
    end
  end

  defp service_graph(dataset) do
    if service_graph = RDF.Dataset.graph(dataset, @service_manifest_graph_name) do
      {:ok, service_graph}
    else
      {:error, ManifestError.exception(data: dataset, reason: :no_service_graph)}
    end
  end
end
