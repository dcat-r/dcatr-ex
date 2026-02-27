defmodule DCATR.Element do
  @moduledoc """
  Abstract base schema for items that can be organized within a `DCATR.Directory`.

  Both `DCATR.Graph` and `DCATR.Directory` inherit from this schema, enabling
  hierarchical containment where directories can hold graphs and nested directories.
  """

  use Grax.Schema

  schema DCATR.Element do
  end
end
