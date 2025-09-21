defmodule DCATR.Service do
  use Grax.Schema

  schema DCATR.Service do
    link repository: DCATR.serviceRepository(), type: DCATR.Repository, required: true
  end
end
