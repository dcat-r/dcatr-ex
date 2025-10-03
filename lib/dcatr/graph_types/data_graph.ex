defmodule DCATR.DataGraph do
  @moduledoc """
  A `DCATR.Graph` containing the actual user data of a `DCATR.Dataset`.

  These are the primary content graphs that form the core of the `DCATR.Repository`'s
  dataset, distinct from system metadata and working areas.
  """

  use Grax.Schema

  schema DCATR.DataGraph < DCATR.Graph do
  end
end
