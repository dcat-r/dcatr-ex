defmodule DCATRTest do
  use DCATR.Case

  doctest DCATR

  {properties, classes} = Enum.split_with(DCATR.NS.DCATR.__terms__(), &RDF.Utils.downcase?/1)
  @classes classes
  @properties properties

  describe "RDF.Vocabulary.Namespace compatibility" do
    Enum.each(@classes, fn class ->
      test "DCATR.#{class} can be resolved to a RDF.IRI" do
        assert DCATR
               |> Module.concat(unquote(class))
               |> RDF.iri() ==
                 DCATR.NS.DCATR
                 |> Module.concat(unquote(class))
                 |> RDF.iri()
      end
    end)

    Enum.each(@properties, fn property ->
      test "DCATR.#{property}/0" do
        assert apply(DCATR, unquote(property), []) ==
                 apply(DCATR.NS.DCATR, unquote(property), [])
      end

      test "DCATR.#{property}/2" do
        assert apply(DCATR, unquote(property), [EX.S, EX.O]) ==
                 apply(DCATR.NS.DCATR, unquote(property), [EX.S, EX.O])
      end

      test "DCATR.#{property}/1" do
        o = RDF.iri(EX.O)
        desc = apply(DCATR.NS.DCATR, unquote(property), [EX.S, o])
        assert apply(DCATR, unquote(property), [desc]) == [o]
      end
    end)

    test "__file__/0" do
      assert DCATR.__file__() == DCATR.NS.DCATR.__file__()
    end
  end
end
