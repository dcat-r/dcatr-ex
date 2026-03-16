defmodule DCATR.DataGraph do
  @moduledoc """
  A `DCATR.Graph` containing user data within a `DCATR.Dataset`.

  Data graphs form the primary content of the repository's dataset - the actual domain data.
  They are always contained in the dataset catalog and distributed with the repository.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.DataGraph < DCATR.Graph do
  end

  def new(id, attrs \\ []) do
    with {:ok, struct} <- build(id, attrs) do
      Grax.validate(struct)
    end
  end

  def new!(id, attrs \\ []), do: bang!(&new/2, [id, attrs])
end
