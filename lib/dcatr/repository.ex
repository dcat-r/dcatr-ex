defmodule DCATR.Repository do
  use Grax.Schema

  # We don't inherit from DCAT.Catalog directly, but by using Grax schema mapping
  # a repository can be accessed as a dcat:Catalog with all properties as Elixir fields
  # via the DCAT.Catalog schema of DCAT.ex.
  schema DCATR.Repository do
    link dataset: DCATR.repositoryDataset(), type: DCATR.Dataset, required: true
  end
end
