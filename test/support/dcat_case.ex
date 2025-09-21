defmodule DCATR.Test.Case do
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
      import RDF, only: [iri: 1, literal: 1, bnode: 1]

      alias RDF.{IRI, BlankNode, Literal, Graph}

      alias unquote(__MODULE__).EX
      @compile {:no_warn_undefined, DCAT.Test.Case.EX}
    end
  end
end
