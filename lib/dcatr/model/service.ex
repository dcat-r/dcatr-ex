defmodule DCATR.Service do
  @moduledoc """
  The operations layer for RDF repository services.

  Following `dcat:DataService`, a `DCATR.Service` represents "a collection of operations that
  provides access to one or more datasets or data processing functions." Services define what
  you can **do** with repository data, while `DCATR.Repository` and `DCATR.Dataset` define
  what data you **have**.

  Services are the top level of the DCAT-R hierarchy, aggregating both distributable repository
  data and service-local configuration:

  ```
  Service (operations)
  ├── ServiceData (local: manifest, working graphs, local system graphs)
  └── Repository (distributed: dataset, manifest, distributed system graphs)
      └── Dataset (user data)
  ```

  Each service consists of three core components:

  - **`repository`** - The distributable repository being served
  - **`local_data`** - Service-local catalog (`DCATR.ServiceData`) with configuration and working graphs
  - **`graph_names`** - Bidirectional mappings between global graph IDs and local names

  Implements the `DCATR.Service.Type` behaviour.

  ## Service Types and Instances

  Different service types define different operations over the same underlying repository:

  - **Versioning services** (like Ontogen) provide commit operations, requiring distributed
    SystemGraphs like history graphs
  - **Query services** provide read-only operations, potentially using local SystemGraphs for
    caching or query optimization
  - **Validation services** provide constraint checking, using SystemGraphs for validation reports
  - **API services** expose HTTP endpoints, managing local working graphs for request processing

  Multiple instances of the same service type can serve the same repository with different
  configurations on different machines. Each instance maintains its own `ServiceData` catalog
  with instance-specific settings, working graphs, and local SystemGraphs.

  ## SystemGraphs for Service Operations

  Many services require persistent data beyond the user-facing `DCATR.Dataset`. DCAT-R provides
  `DCATR.SystemGraph` as the extension point for operational data, with two deployment modes:

  ### Distributed SystemGraphs (in Repository)

  SystemGraphs that are part of repository semantics and should be replicated:

  - **History graphs**: Recording commits, branches, tags (versioning services)
  - **Provenance graphs**: Tracking data origins and transformations
  - **Shared indexes**: Pre-computed structures for query optimization
  - **Inference results**: Materialized reasoning outputs

  These are linked via `dcatr:repositorySystemGraph` and distributed with the repository.

  ### Local SystemGraphs (in ServiceData)

  SystemGraphs that are service-instance-specific and never replicated:

  - **Cache graphs**: Local query result caching
  - **Log graphs**: Service-specific operation logs
  - **Local indexes**: Instance-specific optimization structures

  These are linked via `dcatr:serviceSystemGraph` in the `ServiceData` catalog.

  **Extension Pattern**: See `DCATR.Service.Type` for the complete pattern on how to add
  custom SystemGraphs to your service implementations.

  ## Graph Name Management

  Services maintain **bidirectional graph name mappings** to support dual naming for triple-store
  operations:

  - **Graph IDs** (global): The canonical URIs that identify graphs in the repository
  - **Local graph names** (service-specific): The names used in the service's physical RDF dataset
    (URIs, blank nodes, or the special `:default` atom)

  This distinction enables:

  - **Conflict resolution**: Import graphs whose IDs already exist locally under different names
  - **Stable APIs**: Maintain consistent local names despite changing graph IDs
  - **Default graph handling**: Map the RDF 1.1 default graph (which has no name) to a graph ID
  - **Legacy support**: Accommodate existing datasets with established naming conventions

  Graph name mappings are defined in the `DCATR.ServiceManifestGraph` via `dcatr:localGraphName`
  statements and extracted into the `graph_names` and `graph_names_by_id` fields during service
  loading via the `c:DCATR.Service.Type.load_graph_names/2` callback.

  **Recommendation**: Use graph IDs as local names by default (1:1 mapping). Only use different
  local names when specifically required (e.g., legacy compatibility, explicit `:default` graph).

  This dual naming is critical for triple-store services (like Gno) that need to map between
  logical graph identifiers and physical storage names. For graph access via symbolic selectors
  (e.g., `:primary`, `:service_manifest`), services implement `DCATR.GraphResolver`.

  For details on how to configure services in manifest files, including graph name mappings,
  default graph designation, and the `use_primary_as_default` property, see
  `DCATR.ServiceManifestGraph`.

  ## Lifecycle

  ### Loading from Manifests

  Services are typically loaded from RDF configuration files via the manifest system:

      {:ok, service} = DCATR.Manifest.service(:my_app)

  See `DCATR.Manifest` for details on manifest-based service loading.

  ### Direct Construction

  For testing or programmatic construction, services can be built directly:

      service = DCATR.Service.new!(
        EX.MyService,
        repository: repository,
        local_data: service_data,
        use_primary_as_default: true
      )

  ## Schema Mapping

  Ontologically, `dcatr:Service` is defined as `rdfs:subClassOf dcat:DataService` in the
  DCAT-R vocabulary. However, this Grax schema does not directly inherit from `DCAT.DataService`
  to avoid bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  service is still preserved in the `__additional_statements__` field of the struct.

  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a service as a `dcat:DataService` with all DCAT properties mapped
  to struct fields via the `DCAT.DataService` schema from DCAT.ex:

      service = %DCATR.Service{
        __id__: ~I<http://example.org/service>,
        ...
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
