defmodule DCATR do
  @moduledoc """
  Documentation for `DCATR`.
  """
  import RDF.Namespace

  act_as_namespace DCATR.NS.DCATR

  @doc """
  Returns the configured manifest type for the application.

  Applications with custom manifest types (implementing `DCATR.Manifest.Type`) can set
  this in their config to use their manifest type as the default in tasks like `mix dcatr.init`.

  ## Example

      # config/config.exs
      config :dcatr, :manifest_type, MyApp.Manifest
  """
  def manifest_type, do: Application.get_env(:dcatr, :manifest_type, DCATR.Manifest)
end
