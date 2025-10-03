defmodule DCATR.ManifestGraph do
  @moduledoc """
  Abstract base class for `DCATR.Graph`s containing DCAT descriptions.

  Manifest graphs have a known structure containing DCAT descriptions and configuration
  that define the repository and service structure. DCAT-R depends on this structure
  for proper operation.
  """

  use Grax.Schema

  schema DCATR.ManifestGraph < DCATR.Graph do
  end
end
