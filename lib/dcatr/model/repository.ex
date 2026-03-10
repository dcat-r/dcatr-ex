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
