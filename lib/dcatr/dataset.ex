defmodule DCATR.Dataset do
  use Grax.Schema

  # We don't inherit from DCAT.Catalog directly, but by using Grax schema mapping
  # a dataset can be accessed as a dcat:Catalog with all properties as Elixir fields
  # via the DCAT.Catalog schema of DCAT.ex or similarly as a PROV.Entity schema of PROV.ex.
  schema DCATR.Dataset do
  end
end
