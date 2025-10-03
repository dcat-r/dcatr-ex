defmodule DCATR.ServiceData do
  @moduledoc """
  A catalog of service-specific `DCATR.Graph`s not distributed with the `DCATR.Repository`.

  Contains graphs that are local to a `DCATR.Service` instance:

  - a`DCATR.ServiceManifestGraph` - service configuration
  - a set of `DCATR.WorkingGraph`s - temporary/experimental data
  - a set of service-specific `DCATR.SystemGraph`s

  Typically instantiated as a blank node to avoid managing an additional URI,
  but can have an explicit URI if external referencing is required.

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.Catalog` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata is
  still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing service data as a `dcat:Catalog` with all DCAT properties mapped
  to struct fields via the `DCAT.Catalog` schema from DCAT.ex.
  """

  use Grax.Schema

  schema DCATR.ServiceData do
    link manifest_graph: DCATR.serviceManifestGraph(), type: DCATR.ServiceManifestGraph
    link working_graphs: DCATR.serviceWorkingGraph(), type: list_of(DCATR.WorkingGraph)
    link system_graphs: DCATR.serviceSystemGraph(), type: list_of(DCATR.SystemGraph)
  end

  @type id_or_selector :: :manifest | RDF.IRI.coercible()
  @type graph_type :: :manifest | :working | :system

  @doc """
  Returns a graph by ID or special selector.
  """
  @spec graph(t(), id_or_selector()) :: DCATR.Graph.t() | nil
  def graph(service_data, id_or_selector)
  def graph(%_{manifest_graph: manifest_graph}, :manifest), do: manifest_graph
  def graph(%_{} = service_data, uri), do: find_graph_by_id(service_data, RDF.iri(uri))

  defp find_graph_by_id(%_{manifest_graph: %{__id__: id} = graph}, id), do: graph

  defp find_graph_by_id(%_{} = service_data, id) do
    Enum.find(service_data.working_graphs, fn g -> g.__id__ == id end) ||
      Enum.find(service_data.system_graphs, fn g -> g.__id__ == id end)
  end

  @doc """
  Returns all graphs in the service data catalog.

  ## Options

  - `:type` - filter by type (`:working`, `:system`, `:manifest`) or a list of types

  ## Examples

      # Get all graphs
      ServiceData.graphs(service_data)

      # Get only working graphs
      ServiceData.graphs(service_data, type: :working)

      # Get both manifest and working graphs
      ServiceData.graphs(service_data, type: [:manifest, :working])
  """
  @spec graphs(t(), type: graph_type() | [graph_type()]) :: [DCATR.Graph.t()]
  def graphs(%_service_data_type{} = service_data, opts \\ []) do
    case Keyword.get(opts, :type) do
      nil -> collect_graphs(service_data)
      types when is_list(types) -> Enum.flat_map(types, &graphs(service_data, type: &1))
      :manifest -> List.wrap(service_data.manifest_graph)
      :working -> service_data.working_graphs
      :system -> service_data.system_graphs
      _ -> []
    end
  end

  defp collect_graphs(service_data) do
    (service_data.working_graphs ++ service_data.system_graphs)
    |> maybe_add_graph(service_data.manifest_graph)
  end

  defp maybe_add_graph(graphs, nil), do: graphs
  defp maybe_add_graph(graphs, graph), do: [graph | graphs]

  @doc """
  Returns all working graphs.
  """
  @spec working_graphs(t()) :: [DCATR.WorkingGraph.t()]
  def working_graphs(%_service_data_type{working_graphs: graphs}), do: graphs

  @doc """
  Returns local system graphs.
  """
  @spec system_graphs(t()) :: [DCATR.SystemGraph.t()]
  def system_graphs(%_service_data_type{system_graphs: graphs}), do: graphs

  @doc """
  Checks if a graph exists in the service data.
  """
  @spec has_graph?(t(), id_or_selector()) :: boolean()
  def has_graph?(%_service_data_type{} = service_data, id_or_selector) do
    graph(service_data, id_or_selector) != nil
  end
end
