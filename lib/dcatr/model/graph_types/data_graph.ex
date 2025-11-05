defmodule DCATR.DataGraph do
  @moduledoc """
  A `DCATR.Graph` containing the actual user data of a `DCATR.Dataset`.

  These are the primary content graphs that form the core of the `DCATR.Repository`'s
  dataset, distinct from system metadata and working areas.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.DataGraph < DCATR.Graph do
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])
end
