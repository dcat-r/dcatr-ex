defmodule DCATR.ServiceManifestGraph do
  @moduledoc """
  A `DCATR.ManifestGraph` containing instance-specific configuration of a `DCATR.Service`.

  Service manifest graphs contain service-specific configuration and local settings.
  These graphs are not replicated between service instances and contain the local
  configuration specific to one service instance.

  Blank nodes are allowed as graph IDs for service manifest graphs.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.ServiceManifestGraph < DCATR.ManifestGraph do
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])
end
