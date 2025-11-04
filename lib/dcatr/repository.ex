defmodule DCATR.Repository do
  @moduledoc """
  A distributable data container augmenting a `DCATR.Dataset` with manifest and system graphs as a `dcat:Catalog`.

  Represents a global RDF data container with:

  - a `DCATR.Dataset` - catalog of data graphs (multi-graph mode)
  - a `DCATR.DataGraph` via `primary_graph` - single-graph shortcut OR primary designation
  - a `DCATR.RepositoryManifestGraph` - repository metadata as a DCAT catalog description
  - a set of `DCATR.SystemGraph`s - optional system-level graphs (e.g., history graphs)

  The manifest graph contains the DCAT catalog description of the repository itself,
  including descriptions of the dataset and system graphs.

  ## Primary Graph: Dual-Use Pattern

  The `primary_graph` field serves two purposes: single-graph convenience and primary designation.

  **Single-graph mode** (no dataset needed):

      iex> repo = DCATR.Repository.new!(~I<http://example.org/repo>,
      ...>   primary_graph: DCATR.DataGraph.new!(~I<http://example.org/graph>),
      ...>   manifest_graph: DCATR.RepositoryManifestGraph.new!(~I<http://example.org/manifest>)
      ...> )
      iex> repo.dataset
      nil
      iex> DCATR.Repository.graph(repo, :primary)
      %DCATR.DataGraph{__id__: ~I<http://example.org/graph>}

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

  **Validation**: At least one of `dataset` or `primary_graph` is required. When both are present,
  `primary_graph` must be included in the dataset's graphs.

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.Catalog` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  repository is still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a repository as a `dcat:Catalog` with all DCAT properties mapped
  to struct fields via the `DCAT.Catalog` schema from DCAT.ex:

      repo = %DCATR.Repository{
        __id__: ~I<http://example.org/repo>,
        dataset: %DCATR.Dataset{__id__: ~I<http://example.org/dataset>},
        __additional_statements__: %{
          ~I<http://purl.org/dc/terms/title> => %{
            ~L"My Repository" => nil
          }
        }
      }

      catalog = DCAT.Catalog.from(repo)
      catalog.title
      # => "My Repository"
  """

  use DCATR.Repository.Type

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Repository do
    link dataset: DCATR.repositoryDataset(), type: DCATR.Dataset, depth: +2

    link primary_graph: DCATR.repositoryPrimaryGraph(), type: DCATR.DataGraph, depth: +1

    link manifest_graph: DCATR.repositoryManifestGraph(),
         type: DCATR.RepositoryManifestGraph,
         required: true,
         depth: +1

    link system_graphs: DCATR.repositorySystemGraph(), type: list_of(DCATR.SystemGraph), depth: +1
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])

  @impl true
  def on_validate(%__MODULE__{dataset: nil, primary_graph: nil}, _opts) do
    {:error, "at least one of dataset or primary_graph required"}
  end

  def on_validate(
        %__MODULE__{dataset: %_{graphs: graphs}, primary_graph: %_{__id__: primary_id}},
        _opts
      ) do
    if Enum.any?(graphs, &(&1.__id__ == primary_id)) do
      :ok
    else
      {:error, "primary_graph must be one of the dataset's graphs when both are present"}
    end
  end

  def on_validate(_repo, _opts), do: :ok
end
