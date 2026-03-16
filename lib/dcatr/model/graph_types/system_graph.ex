defmodule DCATR.SystemGraph do
  @moduledoc """
  Base class for `DCATR.Graph`s containing application-specific operational data.

  System graphs store infrastructure that supports service operations but is opaque
  to DCAT-R itself. Examples include version history, provenance records, inference
  results, shared indexes, caches, and logs.

  System graphs can be deployed in two modes:

  - **Distributed** (in `DCATR.Repository`): Replicated with the repository
    (e.g., history graphs, provenance, shared indexes)
  - **Local** (in `DCATR.ServiceData`): Instance-specific and never distributed
    (e.g., caches, logs, local indexes)
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.SystemGraph < DCATR.Graph do
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])
end
