defmodule CustomManifest do
  @moduledoc """
  Custom manifest type for testing.
  """

  use DCATR.Manifest.Type
  use Grax.Schema

  alias RDF.{Dataset, Graph}

  alias DCATR.Case.EX

  schema EX.ManifestType < DCATR.Manifest do
    property foo: EX.foo(), type: :string
  end

  def init_dataset(_opts) do
    {:ok, Dataset.new(Graph.new({EX.S1, EX.P1, EX.O1}))}
  end

  def load_file("ignore.ttl", _), do: {:ok, nil}

  def load_file(file, opts) do
    with {:ok, data} <- super(file, opts) do
      case data do
        %Dataset{} = dataset ->
          {:ok, Dataset.add(dataset, {EX.S2, EX.P2, EX.O2})}
      end
    end
  end

  def load_manifest(manifest, opts) do
    with {:ok, manifest} <- super(manifest, opts) do
      Grax.put(manifest, :foo, "bar")
    end
  end
end
