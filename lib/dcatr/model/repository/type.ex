defmodule DCATR.Repository.Type do
  @moduledoc """
  Behaviour for defining custom repository types with extensible graph catalogs.
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()
  @type graph_type :: :data | :system | :manifest

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
      use DCATR.Catalog
      use Grax.Schema

      @doc """
      Resolves a symbolic selector to a graph.

      This implementation of `c:DCATR.Catalog.resolve_graph_selector/2` delegates to 
      `DCATR.Repository.Type.resolve_graph_selector/2`.
      """
      @impl true
      def resolve_graph_selector(repo, selector) do
        DCATR.Repository.Type.resolve_graph_selector(repo, selector)
      end

      @doc """
      Returns a graph by ID or symbolic selector.

      This implementation of `c:DCATR.Catalog.graph/2` delegates to 
      `DCATR.Repository.Type.graph/2`.
      """
      @impl true
      def graph(repo, selector_or_id) do
        DCATR.Repository.Type.graph(repo, selector_or_id)
      end

      @doc """
      Returns all graphs in the repository.

      This implementation of `c:DCATR.Catalog.graphs/2` delegates to 
      `DCATR.Repository.Type.graphs/2`.
      """
      @impl true
      def graphs(repo, opts \\ []) do
        DCATR.Repository.Type.graphs(repo, opts)
      end

      @doc """
      Returns all system graphs in the repository.

      This implementation of `c:DCATR.Repository.Type.system_graphs/1` delegates to
      `DCATR.Repository.Type.system_graphs/1`.
      """
      @impl true
      def system_graphs(repo) do
        DCATR.Repository.Type.system_graphs(repo)
      end

      @doc """
      Returns the primary graph if one is designated.

      This implementation of `c:DCATR.Repository.Type.primary_graph/1` delegates to
      `DCATR.Repository.Type.primary_graph/1`.
      """
      @impl true
      def primary_graph(repo) do
        DCATR.Repository.Type.primary_graph(repo)
      end

      defoverridable resolve_graph_selector: 2,
                     graph: 2,
                     graphs: 1,
                     graphs: 2,
                     system_graphs: 1,
                     primary_graph: 1
    end
  end

  # Public default implementations (called by __using__ delegation)

  alias DCATR.{Catalog, Dataset, Graph, SystemGraph}

  @doc """
  Default implementation of `c:DCATR.Catalog.resolve_graph_selector/2`.

  Resolves repository-specific selectors, then delegates to the dataset for unknown selectors.

  Supported selectors:

  - `:primary` - Primary graph (when present)
  - `:repository_manifest`, `:repo_manifest` - Repository manifest graph
  """
  @spec resolve_graph_selector(schema(), Catalog.selector()) :: Graph.t() | nil | :undefined
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
  Default implementation of `c:DCATR.Catalog.graph/2`.

  Resolves selectors via `c:DCATR.Catalog.resolve_graph_selector/2`, otherwise searches by ID
  in manifest graph, dataset, and system graphs.
  """
  @spec graph(schema(), Catalog.id_or_selector()) :: Graph.t() | nil
  def graph(%repository_type{} = repository, id_or_selector) do
    case repository_type.resolve_graph_selector(repository, id_or_selector) do
      :undefined -> find_graph_by_id(repository, RDF.coerce_graph_name(id_or_selector))
      result -> result
    end
  end

  defp find_graph_by_id(%_{manifest_graph: %{__id__: id} = graph}, id), do: graph

  defp find_graph_by_id(%_{dataset: dataset} = repository, id) do
    find_primary_graph_by_id(repository, id) ||
      (dataset && Dataset.graph(dataset, id)) ||
      find_system_graph_by_id(repository, id)
  end

  defp find_primary_graph_by_id(%repository_type{} = repository, id) do
    case repository_type.primary_graph(repository) do
      %{__id__: ^id} = graph -> graph
      _ -> nil
    end
  end

  defp find_system_graph_by_id(%repository_type{} = repository, id) do
    repository |> repository_type.system_graphs() |> Enum.find(&(&1.__id__ == id))
  end

  @doc """
  Default implementation of `c:DCATR.Catalog.graphs/2`.

  Returns all graphs (manifest + system + data) by default, or filters by `:type` option.

  ## Options

  - `:type` - Filter by graph type: `:data`, `:system`, `:manifest`, or list of types
  """
  @spec graphs(schema(), type: graph_type() | [graph_type()]) :: [Graph.t()]
  def graphs(%repository_type{} = repository, opts \\ []) do
    case Keyword.get(opts, :type) do
      nil -> collect_graphs(repository)
      :data -> data_graphs(repository)
      :system -> repository_type.system_graphs(repository)
      :manifest -> List.wrap(repository.manifest_graph)
      types when is_list(types) -> Enum.flat_map(types, &graphs(repository, type: &1))
      _ -> []
    end
  end

  defp data_graphs(%_{dataset: dataset}) when not is_nil(dataset), do: Dataset.graphs(dataset)

  defp data_graphs(%repository_type{} = repository) do
    List.wrap(repository_type.primary_graph(repository))
  end

  defp collect_graphs(%repository_type{dataset: nil} = repository) do
    [
      repository.manifest_graph,
      repository_type.primary_graph(repository)
      | repository_type.system_graphs(repository)
    ]
  end

  defp collect_graphs(%repository_type{dataset: dataset} = repository) do
    [
      repository.manifest_graph
      | repository_type.system_graphs(repository) ++ Dataset.graphs(dataset)
    ]
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
