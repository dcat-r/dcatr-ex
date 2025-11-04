defmodule DCATR.Dataset do
  @moduledoc """
  A catalog of the data graphs within a `DCATR.Repository`.

  Each repository contains exactly one such dataset as its primary data container,
  modeled as a DCAT catalog of `DCATR.DataGraph`s.

  Implements the `DCATR.Catalog` behaviour.

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

  use DCATR.Catalog
  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.Dataset do
    link graphs: DCATR.dataGraph(), type: list_of(DCATR.DataGraph), depth: +1
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])

  @doc """
  Returns a `DCATR.DataGraph` by id.
  """
  @impl true
  @spec graph(t(), RDF.IRI.coercible()) :: DCATR.DataGraph.t() | nil
  def graph(%_dataset_type{graphs: graphs}, id) do
    graph_id = RDF.coerce_graph_name(id)
    Enum.find(graphs, fn graph -> graph.__id__ == graph_id end)
  end

  @doc """
  Returns all `DCATR.DataGraph`s in the dataset.
  """
  @impl true
  @spec graphs(t(), keyword()) :: [DCATR.DataGraph.t()]
  def graphs(%_dataset_type{graphs: graphs}, _opts \\ []), do: graphs

  @doc false
  @impl true
  @spec resolve_graph_selector(t(), DCATR.Catalog.selector()) :: :undefined
  def resolve_graph_selector(_dataset, _selector), do: :undefined
end
