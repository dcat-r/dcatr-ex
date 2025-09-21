defmodule DCATR.NS do
  @moduledoc """
  `RDF.Vocabulary.Namespace`s for the used vocabularies.
  """

  use RDF.Vocabulary.Namespace

  @vocabdoc """
  The DCAT for RDF Repositories (DCAT-R) vocabulary.

  See <https://w3id.org/dcat-r
  """
  defvocab DCATR,
    base_iri: "https://w3id.org/dcat-r#",
    file: "dcat-r.ttl",
    case_violations: :fail
end
