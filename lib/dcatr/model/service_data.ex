defmodule DCATR.ServiceData do
  @moduledoc """
  A catalog of service-specific `DCATR.Graph`s not distributed with the `DCATR.Repository`.

  Contains graphs that are local to a `DCATR.Service` instance:

  - a`DCATR.ServiceManifestGraph` - service configuration
  - a set of `DCATR.WorkingGraph`s - temporary/experimental data
  - a set of service-specific `DCATR.SystemGraph`s

  Typically instantiated as a blank node to avoid managing an additional URI,
  but can have an explicit URI if external referencing is required.

  ## Schema Mapping

  This schema does not directly inherit from `DCAT.Catalog` in Grax to avoid
  bloating the Elixir structs with all DCAT properties. Any DCAT metadata is
  still preserved in the `__additional_statements__` field of the struct.
  When needed, [Grax schema mapping](https://rdf-elixir.dev/grax/api.html#mapping-between-schemas)
  allows accessing service data as a `dcat:Catalog` with all DCAT properties mapped
  to struct fields via the `DCAT.Catalog` schema from DCAT.ex.
  """

  use DCATR.ServiceData.Type

  alias DCATR.Directory.LoadHelper

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.ServiceData do
    link manifest_graph: DCATR.serviceManifestGraph(),
         type: DCATR.ServiceManifestGraph,
         required: true,
         depth: +1

    link working_graphs: DCATR.serviceWorkingGraph(), type: list_of(DCATR.WorkingGraph), depth: +1
    link system_graphs: DCATR.serviceSystemGraph(), type: list_of(DCATR.SystemGraph), depth: +1
  end

  def new(id, attrs) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs), do: bang!(&new/2, [id, attrs])

  @impl true
  def on_load(%__MODULE__{} = service_data, %RDF.Graph{} = graph, _opts) do
    LoadHelper.normalize_members(service_data, graph, fn member, acc ->
      cond do
        Grax.Schema.inherited_from?(member, DCATR.ServiceManifestGraph) ->
          LoadHelper.assign_singular(acc, :manifest_graph, member)

        Grax.Schema.inherited_from?(member, DCATR.WorkingGraph) ->
          {:ok, %{acc | working_graphs: [member | acc.working_graphs]}}

        Grax.Schema.inherited_from?(member, DCATR.SystemGraph) ->
          {:ok, %{acc | system_graphs: [member | acc.system_graphs]}}

        true ->
          {:ok, acc}
      end
    end)
  end

  def on_load(_service_data, _description, _opts),
    do: raise(ArgumentError, "on_load requires an RDF.Graph, not an RDF.Description")
end
