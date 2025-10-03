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

      alias unquote(__MODULE__).EX
      @compile {:no_warn_undefined, DCATR.Case.EX}
    end
  end
end
