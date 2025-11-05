defmodule DCATR.ServiceData.Type do
  @moduledoc """
  Behaviour for defining custom service data catalogs with additional local graphs.
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()
  @type graph_type :: :manifest | :working | :system

  @doc """
  Returns all working graphs in the service data.

  Working graphs are temporary or experimental graphs local to the service, not intended
  for distribution with the repository.

  Override to include additional working graphs specific to your service data type.
  """
  @callback working_graphs(service_data :: schema()) :: [DCATR.WorkingGraph.t()]

  @doc """
  Returns all service-local system graphs.

  System graphs at the service level contain service-specific metadata, configuration,
  or operational data.

  Override to include additional service-local system graphs.
  """
  @callback system_graphs(service_data :: schema()) :: [DCATR.SystemGraph.t()]

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.ServiceData.Type
      use DCATR.Catalog
      use Grax.Schema

      @doc """
      Resolves a symbolic selector to a graph.

      This implementation of `c:DCATR.Catalog.resolve_graph_selector/2` delegates to
      `DCATR.ServiceData.Type.resolve_graph_selector/2`.
      """
      @impl true
      def resolve_graph_selector(data, selector) do
        DCATR.ServiceData.Type.resolve_graph_selector(data, selector)
      end

      @doc """
      Returns a graph by ID or symbolic selector.

      This implementation of `c:DCATR.Catalog.graph/2` delegates to
      `DCATR.ServiceData.Type.graph/2`.
      """
      @impl true
      def graph(data, selector_or_id) do
        DCATR.ServiceData.Type.graph(data, selector_or_id)
      end

      @doc """
      Returns all graphs in the service data.

      This implementation of `c:DCATR.Catalog.graphs/2` delegates to
      `DCATR.ServiceData.Type.graphs/2`.
      """
      @impl true
      def graphs(data, opts \\ []) do
        DCATR.ServiceData.Type.graphs(data, opts)
      end

      @doc """
      Returns all working graphs in the service data.

      This implementation of `c:DCATR.ServiceData.Type.working_graphs/1` delegates to
      `DCATR.ServiceData.Type.working_graphs/1`.
      """
      @impl true
      def working_graphs(data) do
        DCATR.ServiceData.Type.working_graphs(data)
      end

      @doc """
      Returns all service-local system graphs.

      This implementation of `c:DCATR.ServiceData.Type.system_graphs/1` delegates to
      `DCATR.ServiceData.Type.system_graphs/1`.
      """
      @impl true
      def system_graphs(data) do
        DCATR.ServiceData.Type.system_graphs(data)
      end

      defoverridable resolve_graph_selector: 2,
                     graph: 2,
                     graphs: 1,
                     graphs: 2,
                     working_graphs: 1,
                     system_graphs: 1
    end
  end

  # Public default implementations (called by __using__ delegation)

  alias DCATR.{Catalog, Graph, SystemGraph, WorkingGraph}

  @doc """
  Default implementation of `c:DCATR.Catalog.resolve_graph_selector/2`.

  Resolves service-data-specific selectors.

  Supported selectors:

  - `:service_manifest` - Service manifest graph
  """
  @spec resolve_graph_selector(schema(), Catalog.selector()) :: Graph.t() | nil | :undefined
  def resolve_graph_selector(service_data, selector)

  def resolve_graph_selector(%_{manifest_graph: manifest_graph}, :service_manifest),
    do: manifest_graph

  def resolve_graph_selector(_service_data, _selector), do: :undefined

  @doc """
  Default implementation of `c:DCATR.Catalog.graph/2`.

  Resolves selectors via `c:resolve_graph_selector/2`, otherwise searches by ID
  in manifest graph, working graphs, and system graphs.
  """
  @spec graph(schema(), Catalog.id_or_selector()) :: Graph.t() | nil
  def graph(%service_data_type{} = service_data, id_or_selector) do
    case service_data_type.resolve_graph_selector(service_data, id_or_selector) do
      :undefined -> find_graph_by_id(service_data, RDF.coerce_graph_name(id_or_selector))
      result -> result
    end
  end

  defp find_graph_by_id(%_{manifest_graph: %{__id__: id} = graph}, id), do: graph

  defp find_graph_by_id(%_{system_graphs: system_graphs, working_graphs: working_graphs}, id) do
    Enum.find(working_graphs, &(&1.__id__ == id)) ||
      Enum.find(system_graphs, &(&1.__id__ == id))
  end

  @doc """
  Default implementation of `c:DCATR.Catalog.graphs/2`.

  Returns all graphs (manifest + system + working) by default, or filters by `:type` option.

  ## Options

  - `:type` - Filter by graph type: `:manifest`, `:working`, `:system`, or list of types
  """
  @spec graphs(schema(), type: graph_type() | [graph_type()]) :: [Graph.t()]
  def graphs(%_service_data_type{} = service_data, opts \\ []) do
    case Keyword.get(opts, :type) do
      nil -> collect_graphs(service_data)
      :manifest -> List.wrap(service_data.manifest_graph)
      :working -> service_data.working_graphs
      :system -> service_data.system_graphs
      types when is_list(types) -> Enum.flat_map(types, &graphs(service_data, type: &1))
      _ -> []
    end
  end

  defp collect_graphs(service_data) do
    [service_data.manifest_graph | service_data.system_graphs ++ service_data.working_graphs]
  end

  @doc """
  Default implementation of `c:working_graphs/1`.

  Returns the `working_graphs` field.
  """
  @spec working_graphs(schema()) :: [WorkingGraph.t()]
  def working_graphs(%_service_data_type{working_graphs: graphs}), do: graphs

  @doc """
  Default implementation of `c:system_graphs/1`.

  Returns the `system_graphs` field.
  """
  @spec system_graphs(schema()) :: [SystemGraph.t()]
  def system_graphs(%_service_data_type{system_graphs: graphs}), do: graphs
end
