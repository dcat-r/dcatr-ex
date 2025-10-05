defmodule DCATR.Repository do
  @moduledoc """
  A distributable data container augmenting a `DCATR.Dataset` with manifest and system graphs as a `dcat:Catalog`.

  Represents a global RDF data container with three components:

  - a `DCATR.Dataset` - the primary data container with data graphs (required)
  - a `DCATR.RepositoryManifestGraph` - repository metadata as a DCAT catalog description
  - a set of `DCATR.SystemGraph`s - optional system-level graphs (e.g., history graphs)

  The manifest graph contains the DCAT catalog description of the repository itself,
  including descriptions of the dataset and system graphs.

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

  use Grax.Schema

  alias DCATR.Dataset

  schema DCATR.Repository do
    link dataset: DCATR.repositoryDataset(), type: DCATR.Dataset, required: true

    link manifest_graph: DCATR.repositoryManifestGraph(),
         type: DCATR.RepositoryManifestGraph,
         required: true

    link system_graphs: DCATR.repositorySystemGraph(), type: list_of(DCATR.SystemGraph)
  end

  @type id_or_selector :: :manifest | RDF.IRI.coercible()
  @type graph_type :: :data | :system | :manifest

  @doc """
  Returns a graph by ID or special selector.
  """
  @spec graph(t(), id_or_selector()) :: DCATR.Graph.t() | nil
  def graph(repository, id_or_selector)
  def graph(%_{manifest_graph: manifest_graph}, :manifest), do: manifest_graph

  def graph(%_{} = repository, id) do
    find_graph_by_id(repository, RDF.coerce_graph_name(id))
  end

  defp find_graph_by_id(%_{manifest_graph: %{__id__: id} = graph}, id), do: graph

  defp find_graph_by_id(%_{} = repo, id) do
    Dataset.graph(repo.dataset, id) ||
      Enum.find(repo.system_graphs, fn graph -> graph.__id__ == id end)
  end

  @doc """
  Returns all graphs in the repository.

  ## Examples

      # Get all graphs
      Repository.graphs(repo)

      # Get manifest and system graphs
      Repository.graphs(repo, type: [:manifest, :system])
  """
  @spec graphs(t(), type: graph_type() | [graph_type()]) :: [DCATR.Graph.t()]
  def graphs(%_repository_type{} = repository, opts \\ []) do
    case Keyword.get(opts, :type) do
      nil -> collect_graphs(repository)
      types when is_list(types) -> Enum.flat_map(types, &graphs(repository, type: &1))
      :data -> if repository.dataset, do: Dataset.graphs(repository.dataset), else: []
      :system -> repository.system_graphs
      :manifest -> List.wrap(repository.manifest_graph)
      _ -> []
    end
  end

  defp collect_graphs(repository) do
    [repository.manifest_graph | repository.system_graphs ++ Dataset.graphs(repository.dataset)]
  end

  @doc """
  Returns local system graphs.
  """
  @spec system_graphs(t()) :: [DCATR.SystemGraph.t()]
  def system_graphs(%_repository_type{system_graphs: graphs}), do: graphs

  @doc """
  Checks if a graph exists in the repository.
  """
  @spec has_graph?(t(), id_or_selector()) :: boolean()
  def has_graph?(%_repository_type{} = repository, graph_id_or_selector) do
    graph(repository, graph_id_or_selector) != nil
  end
end
