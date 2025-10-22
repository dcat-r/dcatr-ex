defmodule DCATR.Manifest.Type do
  @moduledoc """
  Behaviour for defining custom manifest types with extensible logic.

  This module enables applications to create specialized manifest types by extending
  `DCATR.Manifest` with custom properties, loading logic, and resource extraction.
  The behaviour provides a hierarchical callback system with low-level building blocks
  and high-level orchestration points.

  ## Callback Hierarchy

  **Low-level callbacks** (per-file/resource operations):
  - `init_dataset/1` - Initialize empty dataset with optional seed data
  - `graph_name_for_file/2` - Classify files into named graphs during loading
  - `load_file/2` - Load and preprocess individual RDF files

  **High-level callbacks** (pipeline orchestration):
  - `load_dataset/1` - Complete dataset loading pipeline (calls low-level callbacks)
  - `load_manifest/2` - Extract service and additional resources from loaded dataset

  ## Usage

  Custom manifest types should `use DCATR.Manifest.Type` and define a Grax schema
  extending `DCATR.Manifest`:

      defmodule MyApp.Manifest do
        use DCATR.Manifest.Type
        use Grax.Schema

        schema MyApp.NS.ManifestType < DCATR.Manifest do
          property custom_config: MyApp.NS.customConfig(), type: :string
          link agent: MyApp.NS.agent(), type: MyApp.Agent
        end

        @impl true
        def load_manifest(manifest, opts) do
          with {:ok, manifest} <- super(manifest, opts),
               {:ok, agent} <- load_custom_agent(manifest) do
            Grax.put(manifest, :agent, agent)
          end
        end
      end

  The module automatically provides convenience functions for accessing the manifest
  hierarchy: `manifest/1`, `service/1`, `repository/1`, `dataset/1` (with `!` variants).
  """

  alias DCATR.ManifestError
  alias RDF.{Dataset, Graph}

  @type t :: module()
  @type schema :: Grax.Schema.t()

  @doc """
  Returns the path to the template directory used for manifest generation.

  The default implementation points to `DCATR.Manifest.Generator.default_template_dir/0`.
  Override this to provide custom manifest templates for your manifest type.
  """
  @callback generator_template :: String.t()

  @doc """
  Generates manifest files from templates for a project.

  See `DCATR.Manifest.Generator` for details on the generation process which the
  default implementation uses.
  """
  @callback generate(project_dir :: Path.t(), opts :: keyword()) :: :ok | {:error, any()}

  @doc """
  Low-level callback for initializing the manifest dataset before loading files.

  Called by `c:load_dataset/1` at the start of the loading process, before any files
  are read. Override this to inject seed data or perform custom initialization.

  The default implementation `DCATR.Manifest.Loader.init_dataset/1` returns an empty dataset.

  ## Example Override

      @impl true
      def init_dataset(opts) do
        # Add seed triples before file loading
        {:ok, RDF.Dataset.new(...)}
      end
  """
  @callback init_dataset(opts :: keyword()) :: {:ok, Dataset.t()} | {:error, any()}

  @doc """
  Low-level callback for loading and preprocessing a single RDF file.

  Called by `c:load_dataset/1` for each file during the loading process. Override this
  to add custom preprocessing (e.g., template expansion, validation) before the file
  data is merged into the dataset.

  Return `{:ok, nil}` to skip a file (e.g., based on custom filtering logic).

  The default implementation calls `DCATR.Manifest.Loader.load_file/2`.

  ## Example Override

      @impl true
      def load_file(file, opts) do
        cond do
          file =~ ~r/\\.ignore.nt\\./ -> {:ok, nil}  # Skip files matching pattern
          true -> super(file, opts)
        end
      end
  """
  @callback load_file(file :: String.t(), opts :: keyword()) ::
              {:ok, Dataset.t() | Graph.t() | nil} | {:error, any()}

  @doc """
  Low-level callback for determining the graph name for a file during loading.

  Called by `c:load_file/2` to classify loaded graphs. Override this to add custom
  file classification patterns (e.g., based on filename patterns or content inspection).

  The default implementation calls `DCATR.Manifest.Loader.graph_name_for_file/2`.

  ## Example Override

      @impl true
      def graph_name_for_file(file, opts) do
        super(file, opts) ||
          cond do
            file =~ ~r/store\\.(test|dev|prod)\\.(ttl|nt)$/ -> DCATR.Manifest.Loader.service_manifest_graph_name()
            file =~ ~r/history\\./ -> RDF.bnode("history")
            true -> nil
          end
      end
  """
  @callback graph_name_for_file(file :: String.t(), opts :: keyword()) ::
              RDF.Statement.graph_name() | nil

  @doc """
  High-level callback for orchestrating the complete dataset loading process.

  Called by `DCATR.Manifest.Loader.load/2` to load all manifest files and merge them
  into a dataset. Override this to customize the loading pipeline or add dataset-level
  preprocessing after all files are loaded.

  The default implementation calls `DCATR.Manifest.Loader.load_dataset/1`.

  ## Example Override

      @impl true
      def load_dataset(opts) do
        with {:ok, dataset} <- super(opts) do
          preprocess(dataset)
        end
      end
  """
  @callback load_dataset(opts :: keyword()) :: {:ok, Dataset.t()} | {:error, any()}

  @doc """
  High-level callback for extracting and loading resources from the dataset.

  Called by `DCATR.Manifest.Loader.load/2` after the dataset is loaded. Override this
  to load additional resources (e.g., agents, policies) alongside the service.

  The default implementation calls `DCATR.Manifest.Loader.load_manifest/2`.

  ## Options

  - `:service_id` - Explicit service ID (skips auto-detection)

  ## Example Override

      @impl true
      def load_manifest(manifest, opts) do
        with {:ok, manifest} <- super(manifest, opts),
             {:ok, agent} <- Agent.load(manifest.dataset, agent_id(), ...) do
          Grax.put(manifest, :agent, agent)
        end
      end
  """
  @callback load_manifest(schema(), opts :: keyword()) :: {:ok, schema()} | {:error, any()}

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl true
      def generator_template do
        DCATR.Manifest.Generator.default_template_dir()
      end

      @impl true
      def generate(project_dir, opts \\ []) do
        DCATR.Manifest.Generator.generate(__MODULE__, project_dir, opts)
      end

      @impl true
      def init_dataset(opts) do
        DCATR.Manifest.Loader.init_dataset(opts)
      end

      @impl true
      def load_file(file, opts) do
        opts
        |> Keyword.put_new(:manifest_type, __MODULE__)
        |> then(&DCATR.Manifest.Loader.load_file(file, &1))
      end

      @impl true
      def graph_name_for_file(file, opts) do
        DCATR.Manifest.Loader.graph_name_for_file(file, opts)
      end

      @impl true
      def load_dataset(opts) do
        opts
        |> Keyword.put_new(:manifest_type, __MODULE__)
        |> DCATR.Manifest.Loader.load_dataset()
      end

      @impl true
      def load_manifest(manifest, opts) do
        DCATR.Manifest.Loader.load_manifest(manifest, opts)
      end

      @doc """
      Loads the complete manifest with caching support.

      ## Options

      - `:load_path` - Override default load path
      - `:service_id` - Explicit service ID for loading
      - `:reload` - Force cache reload (bypass cache)
      - Additional options passed to `load_dataset/1` and `load_manifest/2`
      """
      @spec manifest(keyword()) :: {:ok, t()} | {:error, ManifestError.t()}
      def manifest(opts \\ []) do
        DCATR.Manifest.Cache.manifest(__MODULE__, opts)
      end

      @doc """
      Loads the manifest or raises on error.
      """
      def manifest!(opts \\ []), do: DCATR.Utils.bang!(&manifest/1, [opts])

      @doc """
      Loads the service from the cached manifest.
      """
      def service(opts \\ []) do
        with {:ok, manifest} <- manifest(opts), do: {:ok, manifest.service}
      end

      @doc """
      Loads the service or raises on error.
      """
      def service!(opts \\ []), do: DCATR.Utils.bang!(&service/1, [opts])

      @doc """
      Loads the repository from the cached manifest's service.
      """
      def repository(opts \\ []) do
        with {:ok, service} <- service(opts), do: {:ok, service.repository}
      end

      @doc """
      Loads the repository or raises on error.
      """
      def repository!(opts \\ []), do: DCATR.Utils.bang!(&repository/1, [opts])

      @doc """
      Loads the dataset from the cached manifest's repository.
      """
      def dataset(opts \\ []) do
        with {:ok, repository} <- repository(opts), do: {:ok, repository.dataset}
      end

      @doc """
      Loads the dataset or raises on error.
      """
      def dataset!(opts \\ []), do: DCATR.Utils.bang!(&dataset/1, [opts])

      @doc """
      Returns the service type module used by this manifest type.

      Extracts the service type from the `:service` link property definition in the
      manifest's Grax schema. Used for type introspection and validation.
      """
      def service_type do
        unquote(__MODULE__).service_type(__MODULE__)
      end

      defoverridable generate: 1,
                     generate: 2,
                     generator_template: 0,
                     init_dataset: 1,
                     load_file: 2,
                     load_dataset: 1,
                     load_manifest: 2,
                     graph_name_for_file: 2,
                     service: 0,
                     service: 1,
                     service!: 0,
                     service!: 1,
                     repository: 0,
                     repository: 1,
                     repository!: 0,
                     repository!: 1,
                     dataset: 0,
                     dataset: 1,
                     dataset!: 0,
                     dataset!: 1
    end
  end

  @doc """
  Returns the service type module for a given manifest type.

  Extracts the `DCATR.Service.Type` from the manifest's `:service` property schema definition.

  ## Examples

      iex> DCATR.Manifest.Type.service_type(DCATR.Manifest)
      DCATR.Service

  """
  @spec service_type(module()) :: module()
  def service_type(manifest_type) do
    case manifest_type.__property__(:service) do
      %Grax.Schema.LinkProperty{type: {:resource, service_type}} -> service_type
      invalid -> raise "Invalid service type on manifest #{manifest_type}: #{inspect(invalid)}"
    end
  end
end
