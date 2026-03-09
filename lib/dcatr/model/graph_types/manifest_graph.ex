defmodule DCATR.ManifestGraph do
  @moduledoc """
  Abstract base class for `DCATR.Graph`s containing DCAT descriptions.

  Manifest graphs have a known structure containing DCAT descriptions and configuration
  that define the repository and service structure. DCAT-R depends on this structure
  for proper operation.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.ManifestGraph < DCATR.Graph do
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])
end
