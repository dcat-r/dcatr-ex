defmodule DCATR.Case do
  @moduledoc """
  Common `ExUnit.CaseTemplate` for DCAT-R tests.
  """

  use ExUnit.CaseTemplate

  use RDF.Vocabulary.Namespace
  defvocab EX, base_iri: "http://example.com/", terms: [], strict: false

  using do
    quote do
      use RDF

      import unquote(__MODULE__)
      import RDF, only: [iri: 1, literal: 1, bnode: 1, bnode: 0]
      import DCATR.TestFactories

      alias RDF.{IRI, BlankNode, Literal}
      alias DCATR.TestData

      alias unquote(__MODULE__).EX
      @compile {:no_warn_undefined, DCATR.Case.EX}

      setup :clean_manifest_cache
    end
  end

  def clean_manifest_cache(_) do
    DCATR.Manifest.Cache.clear()
  end

  def with_application_env(app, key, value, fun) do
    original = Application.get_env(app, key, :__undefined__)
    :ok = Application.put_env(app, key, value)

    try do
      fun.()
    after
      if original == :__undefined__ do
        Application.delete_env(app, key)
      else
        Application.put_env(app, key, original)
      end
    end
  end
end
