defmodule DCATR.WorkingGraph do
  @moduledoc """
  A `DCATR.Graph` for local working areas not included in distributions.

  Working graphs are service-local and form a temporary, non-published area.
  Used for drafts, experiments, temporary work etc.

  Blank nodes are allowed as graph IDs for working graphs.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.WorkingGraph < DCATR.Graph do
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])
end
