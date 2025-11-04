defmodule DCATR.ServiceManifestGraph do
  @moduledoc """
  A `DCATR.ManifestGraph` containing the DCAT DataService description and local configuration of a `DCATR.Service`.

  Service manifest graphs contain service-specific configuration and local settings.
  These graphs are not replicated between service instances and contain the local
  configuration specific to one service instance.

  Blank nodes are allowed as graph IDs for service manifest graphs.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.ServiceManifestGraph < DCATR.ManifestGraph do
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])
end
