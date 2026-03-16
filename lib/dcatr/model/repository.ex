defmodule DCATR.Repository do
  @moduledoc """
  A distributable catalog combining a dataset with operational infrastructure.

  ## What is a Repository?

  A DCAT-R Repository is a **managed collection** following the pattern of software repositories
  (npm, Maven, Git, Docker registries): it combines core content with operational mechanisms to
  support specialized services.

  **Core characteristics:**

  - **Managed Collection**: Like software repositories that combine content with infrastructure
    (npm: modules + metadata, Git: files + history, Maven: artifacts + POMs), a DCATR Repository
    combines a Dataset (user data) with SystemGraphs (operational infrastructure) to support
    service operations.

  - **Distribution Unit**: Defines what is replicated together when sharing across `DCATR.Service`
    instances - dataset, repository manifest, and distributed system graphs. This boundary enables
    multi-instance deployments where different services serve the same repository with
    instance-specific configurations.

  - **Single Dataset Focus**: Unlike standard DCAT catalogs (which catalog multiple independent
    datasets), a Repository focuses on **one cohesive dataset** with rich supporting infrastructure.

  - **Extensible Structure**: Not a fixed schema—different service types extend by adding specialized
    distributed SystemGraphs. Versioning services add HistoryGraphs, inference services add InferenceGraphs,
    API services add shared index graphs, etc.

  - **Self-Describing Catalog**: A Repository is itself a `dcat:Catalog` with rich DCAT metadata in
    its RepositoryManifestGraph, enabling uniform catalog navigation across all hierarchy levels.

  ## Structure

  A repository contains:

  - **Dataset** (`DCATR.Dataset`) - catalog of user data graphs (multi-graph mode)
  - **Data graph** (`DCATR.DataGraph`) - single-graph shortcut via `dcatr:repositoryDataGraph`
  - **Primary graph** (`DCATR.DataGraph`) - semantic designation of the primary graph
  - **Repository manifest** (`DCATR.RepositoryManifestGraph`) - DCAT catalog description (required)
  - **Distributed system graphs** (`DCATR.SystemGraph`) - operational infrastructure replicated with repository
    (e.g., history, provenance, shared indexes)

  The repository manifest contains the DCAT catalog description of the repository itself,
  including descriptions of the dataset and system graphs.

  **Distribution Boundary**: Everything in a Repository is distributed/replicated. For local,
  instance-specific data (service configuration, working graphs, local caches), see `DCATR.ServiceData`.

  ## Primary Graph

  The `primary_graph` field designates the primary graph. How it gets set depends on the mode:

  **Single-graph mode** (via `dcatr:repositoryDataGraph`, no dataset wrapper needed):

      iex> repo = DCATR.Repository.new!(~I<http://example.org/repo>,
      ...>   data_graph: DCATR.DataGraph.new!(~I<http://example.org/graph>),
      ...>   manifest_graph: DCATR.RepositoryManifestGraph.new!(~I<http://example.org/manifest>)
      ...> )
      iex> repo.dataset
      nil
      iex> repo.data_graph
      %DCATR.DataGraph{__id__: ~I<http://example.org/graph>}
      iex> DCATR.Repository.graph(repo, :primary)
      %DCATR.DataGraph{__id__: ~I<http://example.org/graph>}

  `data_graph` is a sub-property of both `repositoryPrimaryGraph` (designation) and `member`
  (containment). When set, it automatically propagates to `primary_graph`.

  **Multi-graph mode** (primary designates default among many):

      iex> main_graph = DCATR.DataGraph.new!(~I<http://example.org/main>)
      iex> repo = DCATR.Repository.new!(~I<http://example.org/repo>,
      ...>   primary_graph: main_graph,
      ...>   dataset: DCATR.Dataset.new!(~I<http://example.org/dataset>,
      ...>     graphs: [
      ...>       main_graph,
      ...>       DCATR.DataGraph.new!(~I<http://example.org/aux>)
      ...>     ]
      ...>   ),
      ...>   manifest_graph: DCATR.RepositoryManifestGraph.new!(~I<http://example.org/manifest>)
      ...> )
      iex> DCATR.Repository.graph(repo, :primary)
      %DCATR.DataGraph{__id__: ~I<http://example.org/main>}

  At least one of `dataset` or `data_graph` is required. When both `dataset` and
  `primary_graph` are present, `primary_graph` must be included in the dataset's graphs.

  ## Extension

  Service types requiring distributed operational data define custom Repository types via
  `DCATR.Repository.Type`. This allows adding specialized SystemGraph fields (e.g., `history_graph`
  for versioning services, `inference_graph` for reasoning services).

  See `DCATR.Service.Type` for the complete extension pattern.

  ## Schema Mapping

  Ontologically, `dcatr:Repository` is defined as `rdfs:subClassOf dcat:Catalog` in the
  DCAT-R vocabulary. However, this Grax schema does not directly inherit from `DCAT.Catalog`
  to avoid bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  repository is still preserved in the `__additional_statements__` field of the struct.

  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a service as a `dcat:Catalog` with all DCAT properties mapped
  to struct fields via the `DCAT.Catalog` schema from DCAT.ex:

      repo = %DCATR.Repository{
        __id__: ~I<http://example.org/repo>,
        dataset: %DCATR.Dataset{__id__: ~I<http://example.org/dataset>},
        __additional_statements__: %{
          ~I<http://purl.org/dc/terms/title> => %{~L"My Repository" => nil}
        }
      }

      catalog = DCAT.Catalog.from(repo)
      catalog.title  # => "My Repository"

  """

  use DCATR.Repository.Type

  alias DCATR.Directory.LoadHelper

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Repository do
    link dataset: DCATR.repositoryDataset(), type: DCATR.Dataset, depth: +2

    link data_graph: DCATR.repositoryDataGraph(), type: DCATR.DataGraph, depth: +1

    link primary_graph: DCATR.repositoryPrimaryGraph(), type: DCATR.DataGraph, depth: +1

    link manifest_graph: DCATR.repositoryManifestGraph(),
         type: DCATR.RepositoryManifestGraph,
         required: true,
         depth: +1

    link system_graphs: DCATR.repositorySystemGraph(), type: list_of(DCATR.SystemGraph), depth: +1
  end

  def new(id, attrs) do
    with {:ok, struct} <- build(id, attrs) do
      struct
      |> propagate_data_graph()
      |> Grax.validate()
    end
  end

  def new!(id, attrs), do: bang!(&new/2, [id, attrs])

  @impl true
  def on_validate(%__MODULE__{dataset: nil, data_graph: nil}, _opts) do
    {:error, "at least one of dataset or data_graph required"}
  end

  def on_validate(
        %__MODULE__{dataset: %_{} = dataset, primary_graph: %_{__id__: primary_id}},
        _opts
      ) do
    if dataset |> DCATR.Dataset.all_graphs() |> Enum.any?(&(&1.__id__ == primary_id)) do
      :ok
    else
      {:error, "primary_graph must be one of the dataset's graphs when both are present"}
    end
  end

  def on_validate(_repo, _opts), do: :ok

  @impl true
  def on_load(%__MODULE__{} = repo, %RDF.Graph{} = graph, _opts) do
    with {:ok, repo} <-
           LoadHelper.normalize_members(repo, graph, fn member, acc ->
             cond do
               Grax.Schema.inherited_from?(member, DCATR.Dataset) ->
                 LoadHelper.assign_singular(acc, :dataset, member)

               Grax.Schema.inherited_from?(member, DCATR.RepositoryManifestGraph) ->
                 LoadHelper.assign_singular(acc, :manifest_graph, member)

               Grax.Schema.inherited_from?(member, DCATR.DataGraph) ->
                 LoadHelper.assign_singular(acc, :data_graph, member)

               Grax.Schema.inherited_from?(member, DCATR.SystemGraph) ->
                 {:ok, %{acc | system_graphs: [member | acc.system_graphs]}}

               true ->
                 {:ok, acc}
             end
           end) do
      {:ok, propagate_data_graph(repo)}
    end
  end

  def on_load(_repo, _description, _opts),
    do: raise(ArgumentError, "on_load requires an RDF.Graph, not an RDF.Description")

  defp propagate_data_graph(%__MODULE__{data_graph: %_{} = data_graph, primary_graph: nil} = repo) do
    %{repo | primary_graph: data_graph}
  end

  defp propagate_data_graph(repo), do: repo
end
