defmodule DCATR.ServiceManifestGraph do
  @moduledoc """
  A `DCATR.ManifestGraph` containing the DCAT DataService description and local configuration of a `DCATR.Service`.

  Service manifest graphs contain service-specific configuration and local settings.
  These graphs are not replicated between service instances and contain the local
  configuration specific to one service instance.
  """

  use Grax.Schema

  schema DCATR.ServiceManifestGraph < DCATR.ManifestGraph do
  end
end
