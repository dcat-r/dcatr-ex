defmodule DCATR.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DCATR.Manifest.Cache
    ]

    opts = [strategy: :one_for_one, name: DCATR.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
