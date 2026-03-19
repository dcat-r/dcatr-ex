defmodule DCATR do
  @moduledoc """
  A framework for services over RDF repositories that implements the DCAT-R specification.

  ## What is DCAT-R?

  [DCAT-R](https://w3id.org/dcatr) (DCAT for RDF Repositories) is an OWL vocabulary extending DCAT 3
  for representing RDF datasets as hierarchical catalog structures.
  It is designed primarily for building specialized RDF repository services - systems that provide 
  operations (versioning, validation, inference, API access) over datasets.
  While DCAT-R can also be useful for simpler use cases like cataloging or organizing read-only data,
  its full power emerges when extended to create custom service types with domain-specific operations
  and supporting infrastructure.

  **How does DCAT-R extend DCAT?**

  1. **Domain specialization**: While DCAT is designed for cataloging data generally, DCAT-R applies
     DCAT's catalog model specifically to **RDF 1.1 datasets** - cataloging the individual graphs
     within RDF datasets rather than arbitrary data files.

  2. **Service as configuration**: While DCAT treats `dcat:DataService` primarily as a catalogable
     metadata object, DCAT-R uses it as **configuration for implementing services**. A DCAT-R service
     is not just described by metadata; it IS the runtime configuration that service implementations
     use to provide operations.

  ## Core Concepts

  DCAT-R organizes RDF repositories through a **multi-layer catalog hierarchy**:

  ![DCAT-R Overview](https://dcat-r.github.io/spec/diagrams/overview.svg)

  ### Service Layer

  The **operations layer** - what you can DO with the data. Services define and implement operations
  like querying, committing changes, validating, or transforming data. A service aggregates both
  distributable repository data and local instance-specific configuration.

  See `DCATR.Service` for details.

  ### Repository Layer

  The **distributable data catalog** - global/static content that can be replicated across service
  instances. Contains the dataset (user data) plus metadata and optional distributed system graphs
  (e.g., history, provenance, shared indexes).

  See `DCATR.Repository` for details.

  ### ServiceData Layer

  The **local data catalog** - instance-specific data that is never distributed. Contains service
  manifests (configuration), working graphs (temporary/draft data), and optional local system
  graphs (e.g., caches, logs, local indexes).

  See `DCATR.ServiceData` for details.

  ### Dataset Layer

  The **pure user data catalog** - free from operational concerns. A dataset is simply a catalog
  of data graphs, always contained within a repository and always distributed.

  See `DCATR.Dataset` for details.

  ## Graph Taxonomy

  DCAT-R defines a complete taxonomy of graph types. Every graph belongs to **exactly one** of four
  disjoint classes:

  ### DataGraph

  Primary user data - the actual content of the dataset. Always contained in the dataset catalog,
  always distributed with the repository.

  See `DCATR.DataGraph` for details.

  ### ManifestGraph

  Configuration that DCAT-R understands and processes. Contains DCAT-R-specific metadata like
  graph name mappings and service settings. Two concrete types:

  - **RepositoryManifestGraph**: Repository metadata (distributed)
  - **ServiceManifestGraph**: Service configuration (local)

  See `DCATR.ManifestGraph` for details.

  ### SystemGraph

  Infrastructure data supporting service operations. Can be deployed in two modes:

  - **Distributed** (in Repository): History, provenance, shared indexes
  - **Local** (in ServiceData): Caches, logs, local indexes

  See `DCATR.SystemGraph` for details.

  ### WorkingGraph

  Temporary/draft data for service-local operations. Always in ServiceData, never distributed.
  Analogous to a working directory in version control systems.

  See `DCATR.WorkingGraph` for details.

  ### Primary Graph

  DCAT-R supports designating a **primary graph** in two ways:
  - `dcatr:repositoryDataGraph` - for single-graph repositories (provides both containment and designation)
  - `dcatr:repositoryPrimaryGraph` - for multi-graph repositories (pure designator, no containment)

  See `DCATR.Repository` for details.

  ## Manifest System

  Services are typically loaded from RDF manifest files via `DCATR.Manifest`, which provides
  hierarchical, environment-aware configuration loading. See `DCATR.Manifest` for details.

  ## Extending DCAT-R

  DCAT-R provides extension points for building specialized service types, from simple cataloging
  to complex operational services.
  The framework is designed primarily for the latter - building specialized services - but remains
  useful for simpler cases without extension.

  ### Extension Pattern

  When building specialized services, the extension pattern is:

  1. **Define operations** - What can users DO with the data? (commit, validate, transform, query, etc.)
  2. **Define SystemGraphs** - What infrastructure do operations need? (history, caches, indexes, etc.)
  3. **Implement via Type behaviours** - Custom types for Service, Repository, and/or ServiceData

  **Example**: A versioning service (like Ontogen) defines commit operations, which require history
  graphs (distributed SystemGraphs). A validation service defines validation operations, which may
  need validation report graphs (could be distributed or local).

  The complete technical pattern is documented in `DCATR.Service.Type`.

  ### Key Extension Points

  - **`DCATR.Service.Type`** - Define service operations and override repository/service-data types
  - **`DCATR.Repository.Type`** - Add distributed SystemGraphs for repository-level infrastructure
  - **`DCATR.ServiceData.Type`** - Add local SystemGraphs for instance-specific infrastructure
  - **`DCATR.GraphResolver`** - Custom graph selectors via `resolve_graph_selector/2`

  ## Further Reading

  - [DCAT-R specification](https://w3id.org/dcatr) - Formal specification
  - [DCAT-R term reference](https://dcat-r.github.io/spec/terms/) - Vocabulary term definitions
  """
  import RDF.Namespace

  act_as_namespace DCATR.NS.DCATR

  @doc """
  Returns the configured manifest type for the application.

  Applications with custom manifest types (implementing `DCATR.Manifest.Type`) can set
  this in their config to use their manifest type as the default in tasks like `mix dcatr.init`.

  ## Example

      # config/config.exs
      config :dcatr, :manifest_type, MyApp.Manifest
  """
  def manifest_type, do: Application.get_env(:dcatr, :manifest_type, DCATR.Manifest)

  defdelegate manifest(opts \\ []), to: DCATR.Manifest
  defdelegate manifest!(opts \\ []), to: DCATR.Manifest

  defdelegate service(opts \\ []), to: DCATR.Manifest
  defdelegate service!(opts \\ []), to: DCATR.Manifest

  defdelegate repository(opts \\ []), to: DCATR.Manifest
  defdelegate repository!(opts \\ []), to: DCATR.Manifest
end
