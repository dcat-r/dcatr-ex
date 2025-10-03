defmodule DCATR.Service do
  @moduledoc """
  A configured instance of a `DCATR.Repository` as a `dcat:DataService`.

  Represents the local configuration and runtime for accessing a `DCATR.Repository`.
  Multiple services can serve the same repository with different configurations.
  A service consists of:

  - a `DCATR.Repository` - the global repository being served (required)
  - a `DCATR.ServiceData` - a catalog of the service-specific graphs (required)
  - Graph name mappings - optional local names for distributed and local graph names

  ## Graph Names

  Services support dual naming for graphs:

  - **Distributed names**: Global URIs used in the repository
  - **Local graph names**: Service-specific names (URIs, blank nodes, or `:default`)

  Graph name mappings are stored in the service manifest graph and allow referencing
  graphs by local graph names instead of their IDs.

  It is recommended to use graph IDs as local graph names by default. Only use
  different local names when required (e.g., for legacy compatibility or when
  working with `:default` graphs).

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.DataService` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  service is still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a service as a `dcat:DataService` with all DCAT properties mapped
  to struct fields via the `DCAT.DataService` schema from DCAT.ex:

      service = %DCATR.Service{
        __id__: ~I<http://example.org/service>,
        repository: %DCATR.Repository{__id__: ~I<http://example.org/repo>},
        local_data: %DCATR.ServiceData{__id__: ~B<service_data>},
        __additional_statements__: %{
          ~I<http://purl.org/dc/terms/title> => %{
            ~L"My Service" => nil
          },
          ~I<http://www.w3.org/ns/dcat#endpointURL> => %{
            ~I<http://example.org/sparql> => nil
          }
        }
      }

      data_service = DCAT.DataService.from(service)
      data_service.title
      # => "My Service"
      data_service.endpoint_url
      # => ~I<http://example.org/sparql>
  """

  use Grax.Schema

  alias DCATR.{Repository, ServiceData}

  schema DCATR.Service do
    link repository: DCATR.serviceRepository(), type: Repository, required: true
    link local_data: DCATR.serviceLocalData(), type: ServiceData, required: true

    field :graph_names, default: %{}
    field :graph_names_by_id, default: %{}
  end

  @type graph_name :: :default | RDF.IRI.t() | RDF.BlankNode.t()
  @type graph_names :: %{graph_name() => RDF.IRI.t()}
  @type graph_names_by_id :: %{RDF.IRI.t() => graph_name()}
  @type id_or_name_or_selector :: :manifest | graph_name() | RDF.IRI.coercible()
  @type graph_type :: Repository.graph_type() | ServiceData.graph_type()

  @doc """
  Returns a graph by ID, selector, or local name.

  Resolution order:

  1. Try as selector (`:manifest`)
  2. Try as graph name (from `graph_names` mapping)
  3. Try as direct graph ID in repository/local_data

  This is a convenience function - use specific functions for better performance.
  """
  @spec graph(t(), id_or_name_or_selector()) :: DCATR.Graph.t() | nil
  def graph(service, id_or_name)

  def graph(%_service_type{} = service, :manifest) do
    if service.local_data, do: ServiceData.graph(service.local_data, :manifest)
  end

  def graph(%_service_type{} = service, %RDF.BlankNode{} = bnode) do
    graph_by_name(service, bnode)
  end

  def graph(%_service_type{} = service, iri) do
    graph_by_name(service, iri) || graph_by_id(service, iri)
  end

  @doc """
  Returns a graph by its original ID.
  """
  @spec graph_by_id(t(), RDF.IRI.coercible()) :: DCATR.Graph.t() | nil
  def graph_by_id(%_service_type_{repository: repository, local_data: local_data}, id) do
    iri = RDF.iri(id)

    Repository.graph(repository, iri) || (local_data && ServiceData.graph(local_data, iri))
  end

  @doc """
  Returns a graph by its local name.
  """
  @spec graph_by_name(t(), graph_name()) :: DCATR.Graph.t() | nil
  def graph_by_name(%_service_type{graph_names: names} = service, :default) do
    if graph_id = Map.get(names, :default) do
      graph_by_id(service, graph_id)
    end
  end

  def graph_by_name(%_service_type{graph_names: names} = service, graph_name) do
    if graph_id = Map.get(names, RDF.coerce_graph_name(graph_name)) do
      graph_by_id(service, graph_id)
    end
  end

  @doc """
  Returns all graphs accessible through the service.
  """
  @spec graphs(t(), type: graph_type() | [graph_type()]) :: [DCATR.Graph.t()]
  def graphs(%_service_type{} = service, opts \\ []) do
    Repository.graphs(service.repository, opts) ++ ServiceData.graphs(service.local_data, opts)
  end

  @doc """
  Checks if a graph exists in the service.
  """
  @spec has_graph?(t(), id_or_name_or_selector()) :: boolean()
  def has_graph?(%_service_type{} = service, id_or_ref_or_local_name) do
    graph(service, id_or_ref_or_local_name) != nil
  end

  @doc """
  Returns the local name for a graph.
  """
  @spec graph_name(t(), :manifest | DCATR.Graph.t() | RDF.IRI.coercible()) :: graph_name() | nil
  def graph_name(service, graph_or_id_or_ref)

  def graph_name(%_service_type{} = service, :manifest) do
    if manifest_graph = graph(service, :manifest) do
      graph_name(service, manifest_graph)
    end
  end

  def graph_name(%_service_type{} = service, %{__id__: id}), do: graph_name(service, id)

  def graph_name(%_service_type{graph_names_by_id: names_by_id}, id) do
    Map.get(names_by_id, RDF.iri(id))
  end

  @doc """
  Returns the default graph if one is designated.
  """
  @spec default_graph(t()) :: DCATR.Graph.t() | nil
  def default_graph(%_service_type{} = service) do
    graph_by_name(service, :default)
  end

  @doc """
  Returns the complete local name to graph mapping.
  """
  @spec graph_name_mapping(t()) :: graph_names()
  def graph_name_mapping(%_service_type{graph_names: names}), do: names || %{}

  @doc """
  Adds a graph name mapping to the service.
  """
  @spec add_graph_name(t(), graph_name() | RDF.IRI.coercible(), RDF.IRI.coercible()) ::
          {:ok, t()} | {:error, Exception.t()}
  def add_graph_name(%_service_type{} = service, graph_name, graph_id) do
    graph_id = RDF.iri(graph_id)
    graph_name = if graph_name == :default, do: :default, else: RDF.coerce_graph_name(graph_name)

    cond do
      Map.has_key?(service.graph_names, graph_name) ->
        {:error, %DCATR.DuplicateGraphNameError{name: graph_name}}

      not has_graph?(service, graph_id) ->
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

  @impl Grax.Callbacks
  def on_load(service, graph, _opts) do
    with {:ok, service} <- extract_name_mappings(service, graph),
         {:ok, service} <- extract_default_graph(service, graph) do
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
        graph_ids = Enum.map(multiple, fn %{default_graph: id} -> id end)
        {:error, %DCATR.DuplicateGraphNameError{name: :default, graph_ids: graph_ids}}
    end
  end
end
