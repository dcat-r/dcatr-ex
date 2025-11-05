defmodule DCATR.Graph do
  @moduledoc """
  Abstract base schema for all graphs in a DCAT-R repository.

  Represents a graph as a `dcat:Dataset`. Every graph must belong to exactly
  one of the four concrete subclasses:

  - `DCATR.DataGraph` (user data)
  - `DCATR.WorkingGraph` (temporary working areas)
  - `DCATR.ManifestGraph` (DCAT-R configuration)
  - `DCATR.SystemGraph` (system mechanisms)

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.Dataset` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  graph is still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a graph as a `dcat:Dataset` with all DCAT properties mapped
  to struct fields via the `DCAT.Dataset` schema from DCAT.ex:

      graph = %DCATR.DataGraph{
        __id__: ~I<http://example.org/graph1>,
        __additional_statements__: %{
          ~I<http://purl.org/dc/terms/title> => %{
            ~L"My Graph" => nil
          }
        }
      }

      dataset = DCAT.Dataset.from(graph)
      dataset.title
      # => "My Graph"
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Graph do
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])
end
