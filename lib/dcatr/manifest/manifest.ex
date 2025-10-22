defmodule DCATR.Manifest do
  @moduledoc """
  Default manifest type providing hierarchical access to DCAT-R service configuration.

  A manifest is a container struct that holds the complete loaded configuration for a
  DCAT-R service. It provides access to the service hierarchy (Service → Repository →
  Dataset) and maintains the raw RDF dataset and load path used during loading.

  ## Design Rationale

  The manifest is implemented as a Grax schema to provide extensibility through Grax
  subclassing** - Applications can extend `DCATR.Manifest` with custom properties and links,
  creating specialized manifest types while preserving the base service hierarchy access.

  The manifest struct serves as an extensible token that flows through the loading pipeline  
  (`load_dataset/1` → `load_manifest/2`), allowing custom manifest types to inject 
  application-specific data at each stage.

  ## Structure

  - `:service` - The loaded `DCATR.Service` with full repository hierarchy
  - `:dataset` - The complete RDF dataset from which the service was loaded
  - `:load_path` - The load path used for file discovery

  ## Usage

  `DCATR.Manifest` uses the `DCATR.Manifest.Type` behavior, which automatically provides
  convenience functions for accessing the manifest hierarchy:

      # Load complete manifest
      {:ok, manifest} = DCATR.Manifest.manifest()

      # Direct access to service (cached)
      {:ok, service} = DCATR.Manifest.service()

      # Direct access to repository (cached)
      {:ok, repository} = DCATR.Manifest.repository()

      # Direct access to dataset (cached)
      {:ok, dataset} = DCATR.Manifest.dataset()

      # Bang variants raise on error
      service = DCATR.Manifest.service!()

  All functions support options for custom load paths, explicit service IDs, and cache control.

  ## Loading Process

  Manifests are loaded via `DCATR.Manifest.Cache` with the following pipeline:

  1. Resolve load path (see `DCATR.Manifest.LoadPath`)
  2. Load and merge RDF files into dataset (see `DCATR.Manifest.Loader`)
  3. Extract and validate service from dataset
  4. Cache result for subsequent access

  ## Custom Manifest Types

  Applications can create specialized manifest types by extending `DCATR.Manifest`:

      defmodule MyApp.Manifest do
        use DCATR.Manifest.Type
        use Grax.Schema

        schema MyApp.NS.ManifestType < DCATR.Manifest do
          property custom_config: MyApp.NS.customConfig(), type: :string
        end
      end

  See `DCATR.Manifest.Type` for details on customization patterns.
  """

  use DCATR.Manifest.Type
  use Grax.Schema

  alias DCATR.Manifest.Loader

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Manifest do
    link service: DCATR.manifestService(), type: DCATR.Service, required: true

    field :dataset, required: true
    field :load_path, required: true
  end

  @environments Application.compile_env(:dcatr, :environments, ~w[prod dev test]a)

  # Note: We can't use `Mix.env/0` directly because:
  # - At compile time, when DCATR is used as a dependency, `Mix.env/0` would always return `:prod`
  # - At runtime, `Mix.env/0` is not available since Mix is not part of releases
  @env Application.compile_env(:dcatr, :env)

  @doc """
  Returns the currently configured environment for manifest loading.

  The environment determines which manifest files are loaded (base vs environment-specific).
  See `DCATR.Manifest.LoadPath` for file resolution details.

  ## Configuration

  Resolved in order of precedence:

  1. `:env` option (passed as argument)
  2. `DCATR_ENV` environment variable
  3. `MIX_ENV` environment variable
  4. `:dcatr, :env` application config

  Example:

      config :dcatr, env: Mix.env()

  Raises if no environment is configured. Only environments from `environments/0` are valid.
  """
  @spec env(keyword()) :: atom()
  def env(opts \\ []) do
    opts
    |> Keyword.get(
      :env,
      System.get_env("DCATR_ENV") || System.get_env("MIX_ENV") || @env ||
        raise("""
        No environment configured. Please set the :dcatr environment via the `:env` configuration option:

            config :dcatr, env: Mix.env()

        Alternatively, you can set the environment via the `DCATR_ENV` or `MIX_ENV` environment variables.
        """)
    )
    |> to_env()
  end

  defp to_env(env) when is_binary(env),
    do: env |> String.downcase() |> String.to_atom() |> to_env()

  defp to_env(env) when env in @environments, do: env

  defp to_env(env),
    do: raise("Invalid environment: #{inspect(env)}; must be one of #{inspect(@environments)}")

  @doc """
  Returns the supported environments for `env/1`.

  The environments are configured via the `:environments` configuration option
  and defaults to `#{inspect(@environments)}`:

      config :dcatr, :environments, [:prod, :dev, :test, :ci]
  """
  @spec environments() :: [atom()]
  def environments, do: @environments

  @doc """
  Returns the service manifest graph, renamed to its final graph name if available.

  When called with a loaded `Manifest`, returns the graph renamed per `dcatr:serviceManifestGraph`.
  When called with a raw `Dataset` (during loading), returns the graph with its well-known blank node name in an `:ok` tuple.
  """
  @spec service_manifest_graph(t()) :: RDF.Graph.t() | nil
  def service_manifest_graph(%_manifest_type{dataset: dataset, service: service}) do
    graph = service_manifest_graph!(dataset)
    name = service_manifest_graph_name(service)

    if graph && name do
      RDF.Graph.change_name(graph, name)
    else
      graph
    end
  end

  @spec service_manifest_graph(RDF.Dataset.t()) :: {:ok, RDF.Graph.t()} | {:error, any()}
  def service_manifest_graph(%RDF.Dataset{} = dataset) do
    if service_graph = RDF.Dataset.graph(dataset, Loader.service_manifest_graph_name()) do
      {:ok, service_graph}
    else
      {:error, DCATR.ManifestError.exception(data: dataset, reason: :no_service_graph)}
    end
  end

  def service_manifest_graph!(dataset), do: bang!(&service_manifest_graph/1, [dataset])

  @doc """
  Returns the repository manifest graph, renamed to its final graph name if available.

  When called with a loaded `Manifest`, returns the graph renamed per `dcatr:repositoryManifestGraph`.
  When called with a raw `Dataset` (during loading), returns the graph with its well-known blank node name in an `:ok` tuple.
  """
  @spec repository_manifest_graph(t() | RDF.Dataset.t()) :: RDF.Graph.t() | nil
  def repository_manifest_graph(%_manifest_type{dataset: dataset, service: service}) do
    graph = repository_manifest_graph!(dataset)
    name = repository_manifest_graph_name(service)

    if graph && name do
      RDF.Graph.change_name(graph, name)
    else
      graph
    end
  end

  @spec repository_manifest_graph(RDF.Dataset.t()) :: {:ok, RDF.Graph.t()} | {:error, any()}
  def repository_manifest_graph(%RDF.Dataset{} = dataset) do
    if repo_graph = RDF.Dataset.graph(dataset, Loader.repository_manifest_graph_name()) do
      {:ok, repo_graph}
    else
      {:error, DCATR.ManifestError.exception(data: dataset, reason: :no_repository_graph)}
    end
  end

  def repository_manifest_graph!(dataset), do: bang!(&repository_manifest_graph/1, [dataset])

  defp service_manifest_graph_name(%_{local_data: %{manifest_graph: %{__id__: id}}}), do: id
  defp service_manifest_graph_name(_), do: nil
  defp repository_manifest_graph_name(%_{repository: %{manifest_graph: %{__id__: id}}}), do: id
  defp repository_manifest_graph_name(_), do: nil
end
