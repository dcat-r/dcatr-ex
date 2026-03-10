defmodule DCATR.Dataset do
  @moduledoc """
  A catalog of the data graphs within a `DCATR.Repository`.

  Each repository contains exactly one such dataset as its primary data container,
  modeled as a DCAT catalog of `DCATR.DataGraph`s. As the root `DCATR.Directory`
  of the graph hierarchy, it can also contain nested `DCATR.Directory`s for
  hierarchical organization.

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.Catalog` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata on a
  dataset is still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing a dataset as a `dcat:Catalog` with all DCAT properties mapped
  to struct fields via the `DCAT.Catalog` schema from DCAT.ex:

      dataset = %DCATR.Dataset{
        __id__: ~I<http://example.org/dataset1>,
        __additional_statements__: %{
          ~I<http://purl.org/dc/terms/title> => %{
            ~L"My Dataset" => nil
          }
        }
      }

      catalog = DCAT.Catalog.from(dataset)
      catalog.title
      # => "My Dataset"

      entity = PROV.Entity.from(dataset)
  """

  use DCATR.Directory.Type
  use DCATR.GraphResolver

  alias DCATR.Directory.LoadHelper

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Dataset do
    link graphs: DCATR.dataGraph(), type: list_of(DCATR.DataGraph), depth: +1
    link directories: DCATR.directory(), type: list_of(DCATR.Directory), depth: +1
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])

  @impl DCATR.Directory.Type
  def graphs(%_dataset{graphs: graphs}), do: graphs

  @impl DCATR.Directory.Type
  def directories(%_dataset{directories: directories}), do: directories || []

  @impl DCATR.GraphResolver
  def resolve_graph_selector(_dataset, _selector), do: :undefined

  @impl true
  def on_load(%__MODULE__{} = dataset, %RDF.Graph{} = graph, _opts) do
    LoadHelper.normalize_members(dataset, graph, fn member, acc ->
      if Grax.Schema.inherited_from?(member, DCATR.Graph),
        do: {:ok, %{acc | graphs: [member | acc.graphs]}},
        else: {:ok, %{acc | directories: [member | acc.directories]}}
    end)
  end

  def on_load(_dataset, _description, _opts),
    do: raise(ArgumentError, "on_load requires an RDF.Graph, not an RDF.Description")
end
