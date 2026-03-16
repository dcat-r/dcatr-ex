defmodule DCATR.Repository.Type do
  @moduledoc """
  Behaviour for defining custom repository types with extensible graph catalogs.

  `DCATR.Repository`s are the core catalog layer in DCAT-R. This behaviour enables applications to
  create specialized repository types with custom graph collections and selector logic.

  ## Graph Structure

  A repository contains:
  - **dataset** - Primary catalog of DataGraphs (user data)
  - **manifest_graph** - Repository manifest (RepositoryManifestGraph)
  - **system_graphs** - Optional repository-level graphs (e.g., history, provenance)

  ## Callbacks

  - `c:system_graphs/1` - Returns additional system-level graphs
  - `c:primary_graph/1` - Returns the primary graph if one is designated

  Inherits from `DCATR.Directory.Type`:

  - `c:DCATR.Directory.Type.graphs/1`, `c:DCATR.Directory.Type.directories/1`

  Inherits from `DCATR.GraphResolver`:

  - `c:DCATR.GraphResolver.resolve_graph_selector/2`

  ## Standard Selectors

  - `:primary` - Primary graph (when present)
  - `:repository_manifest`, `:repo_manifest` - Repository metadata graph

  ## Usage

  Custom repository types should `use DCATR.Repository.Type` and define a Grax schema
  extending `DCATR.Repository`:

      defmodule MyApp.Repository do
        use DCATR.Repository.Type

        schema MyApp.NS.Repository < DCATR.Repository do
          link history_graph: MyApp.NS.history(), type: MyApp.HistoryGraph
        end

        @impl true
        def resolve_graph_selector(repo, :history), do: repo.history_graph
        def resolve_graph_selector(repo, selector), do: super(repo, selector)

        @impl true
        def system_graphs(repo) do
          [repo.history_graph | super(repo)]
        end
      end

  The module automatically provides delegating implementations of all callbacks
  and convenience functions, all of which are overridable.
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()

  @doc """
  Returns all system graphs in the repository.

  System graphs are repository-level graphs not part of the primary dataset
  (e.g., history graphs, provenance graphs).

  Override to include additional system-level graphs specific to your repository type.
  """
  @callback system_graphs(repository :: schema()) :: [DCATR.SystemGraph.t()]

  @doc """
  Returns the primary graph if one is designated.

  Override to customize primary graph selection.
  """
  @callback primary_graph(repository :: schema()) :: DCATR.DataGraph.t() | nil

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.Repository.Type
      use DCATR.Directory.Type
      use DCATR.GraphResolver

      @doc """
      Resolves a symbolic selector to a graph.

      This implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2` delegates to
      `DCATR.Repository.Type.resolve_graph_selector/2`.
      """
      @impl DCATR.GraphResolver
      def resolve_graph_selector(repo, selector) do
        DCATR.Repository.Type.resolve_graph_selector(repo, selector)
      end

      @doc """
      Returns all direct graphs in the repository.

      This implementation of `c:DCATR.Directory.Type.graphs/1` delegates to
      `DCATR.Repository.Type.graphs/1`.
      """
      @impl DCATR.Directory.Type
      def graphs(repo), do: DCATR.Repository.Type.graphs(repo)

      @doc """
      Returns all direct directories in the repository.

      This implementation of `c:DCATR.Directory.Type.directories/1` delegates to
      `DCATR.Repository.Type.directories/1`.
      """
      @impl DCATR.Directory.Type
      def directories(repo), do: DCATR.Repository.Type.directories(repo)

      @doc """
      Returns all system graphs in the repository.

      This implementation of `c:DCATR.Repository.Type.system_graphs/1` delegates to
      `DCATR.Repository.Type.system_graphs/1`.
      """
      @impl DCATR.Repository.Type
      def system_graphs(repo) do
        DCATR.Repository.Type.system_graphs(repo)
      end

      @doc """
      Returns the primary graph if one is designated.

      This implementation of `c:DCATR.Repository.Type.primary_graph/1` delegates to
      `DCATR.Repository.Type.primary_graph/1`.
      """
      @impl DCATR.Repository.Type
      def primary_graph(repo) do
        DCATR.Repository.Type.primary_graph(repo)
      end

      defoverridable resolve_graph_selector: 2,
                     directories: 1,
                     system_graphs: 1,
                     primary_graph: 1
    end
  end

  # Public default implementations (called by __using__ delegation)

  alias DCATR.{GraphResolver, Dataset, Graph, SystemGraph}

  @doc """
  Default implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2`.

  Resolves repository-specific selectors, then delegates to the dataset for unknown selectors.

  Supported selectors:

  - `:primary` - Primary graph (when present)
  - `:repository_manifest`, `:repo_manifest` - Repository manifest graph
  """
  @spec resolve_graph_selector(schema(), GraphResolver.selector()) :: Graph.t() | nil | :undefined
  def resolve_graph_selector(repository, selector)

  def resolve_graph_selector(%repository_type{} = repository, :primary),
    do: repository_type.primary_graph(repository)

  def resolve_graph_selector(%_{manifest_graph: manifest_graph}, :repository_manifest),
    do: manifest_graph

  def resolve_graph_selector(%_{manifest_graph: manifest_graph}, :repo_manifest),
    do: manifest_graph

  def resolve_graph_selector(%_{dataset: %dataset_type{} = dataset}, selector),
    do: dataset_type.resolve_graph_selector(dataset, selector)

  def resolve_graph_selector(_repository, _selector), do: :undefined

  @doc """
  Default implementation of `c:DCATR.Directory.Type.graphs/1` for repositories.

  Returns direct graph members: `data_graph` (when present), manifest, and system graphs.
  In multi-graph mode (with dataset), `data_graph` is `nil` and the data graphs are reached
  via dataset traversal.
  """
  @spec graphs(schema()) :: [Graph.t()]
  def graphs(%repository_type{} = repository) do
    [repository.data_graph, repository.manifest_graph | repository_type.system_graphs(repository)]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Default implementation of `c:DCATR.Directory.Type.directories/1` for repositories.

  Returns the dataset as the sole sub-directory (when present).
  """
  @spec directories(schema()) :: [Dataset.t()]
  def directories(%_repository_type{dataset: dataset}) do
    List.wrap(dataset)
  end

  @doc """
  Default implementation of `c:system_graphs/1`.

  Returns the `system_graphs` field.
  """
  @spec system_graphs(schema()) :: [SystemGraph.t()]
  def system_graphs(%_repository_type{system_graphs: graphs}), do: graphs

  @doc """
  Default implementation of `c:primary_graph/1`.

  Returns the `primary_graph` field.
  """
  @spec primary_graph(schema()) :: DCATR.DataGraph.t() | nil
  def primary_graph(%_repository_type{primary_graph: primary_graph}), do: primary_graph
end
