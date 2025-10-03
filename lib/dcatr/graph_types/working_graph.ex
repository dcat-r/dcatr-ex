defmodule DCATR.WorkingGraph do
  @moduledoc """
  A `DCATR.Graph` for local working areas not included in distributions.

  Working graphs are service-local and form a temporary, non-published area.
  Used for drafts, experiments, temporary work etc.
  """

  use Grax.Schema

  schema DCATR.WorkingGraph < DCATR.Graph do
  end
end
