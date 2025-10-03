defmodule DCATR.SystemGraph do
  @moduledoc """
  Base class for `DCATR.Graph`s for system-level operational data and mechanisms.

  Examples include history graphs (e.g. `Ontogen.History`), indexes, or
  application-specific operational data.
  """

  use Grax.Schema

  schema DCATR.SystemGraph < DCATR.Graph do
  end
end
