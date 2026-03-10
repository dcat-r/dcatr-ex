defmodule DCATR.ServiceData.Type do
  @moduledoc """
  Behaviour for defining custom service data catalogs with additional local graphs.
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()

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
      use DCATR.Directory.Type
      use DCATR.GraphResolver

      @doc """
      Resolves a symbolic selector to a graph.

      This implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2` delegates to
      `DCATR.ServiceData.Type.resolve_graph_selector/2`.
      """
      @impl DCATR.GraphResolver
      def resolve_graph_selector(data, selector) do
        DCATR.ServiceData.Type.resolve_graph_selector(data, selector)
      end

      @doc """
      Returns all direct graphs in the service data.

      This implementation of `c:DCATR.Directory.Type.graphs/1` delegates to
      `DCATR.ServiceData.Type.graphs/1`.
      """
      @impl DCATR.Directory.Type
      def graphs(sd), do: DCATR.ServiceData.Type.graphs(sd)

      @doc """
      Returns all direct directories in the service data.

      This implementation of `c:DCATR.Directory.Type.directories/1` always returns an empty list,
      as service data does not contain sub-directories.
      """
      @impl DCATR.Directory.Type
      def directories(_sd), do: []

      @doc """
      Returns all working graphs in the service data.

      This implementation of `c:DCATR.ServiceData.Type.working_graphs/1` delegates to
      `DCATR.ServiceData.Type.working_graphs/1`.
      """
      @impl DCATR.ServiceData.Type
      def working_graphs(data) do
        DCATR.ServiceData.Type.working_graphs(data)
      end

      @doc """
      Returns all service-local system graphs.

      This implementation of `c:DCATR.ServiceData.Type.system_graphs/1` delegates to
      `DCATR.ServiceData.Type.system_graphs/1`.
      """
      @impl DCATR.ServiceData.Type
      def system_graphs(data) do
        DCATR.ServiceData.Type.system_graphs(data)
      end

      defoverridable resolve_graph_selector: 2,
                     working_graphs: 1,
                     system_graphs: 1
    end
  end

  # Public default implementations (called by __using__ delegation)

  alias DCATR.{Catalog, Graph, SystemGraph, WorkingGraph}

  @doc """
  Default implementation of `c:DCATR.GraphResolver.resolve_graph_selector/2`.

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
  Default implementation of `c:DCATR.Directory.Type.graphs/1` for service data.

  Returns all graph members: manifest, working graphs, and system graphs.
  """
  @spec graphs(schema()) :: [Graph.t()]
  def graphs(%service_data_type{} = service_data) do
    [
      service_data.manifest_graph
      | service_data_type.working_graphs(service_data) ++
          service_data_type.system_graphs(service_data)
    ]
    |> Enum.reject(&is_nil/1)
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
