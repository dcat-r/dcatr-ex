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

  use DCATR.Service.Type

  import DCATR.Utils, only: [bang!: 2]

  alias DCATR.{Repository, ServiceData}

  schema DCATR.Service do
    link repository: DCATR.serviceRepository(), type: Repository, required: true, depth: false
    link local_data: DCATR.serviceLocalData(), type: ServiceData, required: true, depth: +1

    property use_primary_as_default: DCATR.usePrimaryAsDefault(), type: :boolean

    field :graph_names, default: %{}
    field :graph_names_by_id, default: %{}
  end

  @type graph_name :: :default | RDF.IRI.t() | RDF.BlankNode.t()
  @type graph_names :: %{graph_name() => RDF.IRI.t()}
  @type graph_names_by_id :: %{RDF.IRI.t() => graph_name()}

  def new(id, attrs) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs), do: bang!(&new/2, [id, attrs])
end
