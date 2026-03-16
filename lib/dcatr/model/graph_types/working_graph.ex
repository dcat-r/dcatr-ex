defmodule DCATR.WorkingGraph do
  @moduledoc """
  A `DCATR.Graph` for temporary, service-local working areas.

  Working graphs are never distributed. They serve as staging areas, draft spaces,
  caches, or experimental work areas - analogous to a working directory in version
  control systems.

  Blank nodes are allowed as graph IDs for working graphs.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.WorkingGraph < DCATR.Graph do
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])
end
