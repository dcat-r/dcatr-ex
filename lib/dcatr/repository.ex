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

  use DCATR.Repository.Type

  schema DCATR.Repository do
    link dataset: DCATR.repositoryDataset(), type: DCATR.Dataset, required: true, depth: +1

    link manifest_graph: DCATR.repositoryManifestGraph(),
         type: DCATR.RepositoryManifestGraph,
         required: true,
         depth: +1

    link system_graphs: DCATR.repositorySystemGraph(), type: list_of(DCATR.SystemGraph), depth: +1
  end
end
