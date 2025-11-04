defmodule DCATR.SystemGraph do
  @moduledoc """
  Base class for `DCATR.Graph`s for system-level operational data and mechanisms.

  Examples include history graphs (e.g. `Ontogen.History`), indexes, or
  application-specific operational data.
  """

  use Grax.Schema

  import DCATR.Utils, only: [bang!: 2]

  schema DCATR.SystemGraph < DCATR.Graph do
  end

  def new(id, opts \\ []) do
    with {:ok, struct} <- build(id, opts) do
      Grax.validate(struct)
    end
  end

  def new!(id, opts \\ []), do: bang!(&new/2, [id, opts])
end
