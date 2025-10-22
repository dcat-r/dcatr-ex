defmodule DCATR.Service.TypeTest do
  use DCATR.Case

  doctest DCATR.Service.Type

  alias DCATR.Service

  describe "add_graph_name/3" do
    setup :example_service_scenario

    test "adds a new graph name mapping", %{service: service, system_graphs: [graph | _]} do
      assert {:ok, updated} = Service.Type.add_graph_name(service, EX.NewName, EX.SystemGraph1)

      assert updated.graph_names[RDF.iri(EX.NewName)] == RDF.iri(EX.SystemGraph1)
      assert updated.graph_names_by_id[RDF.iri(EX.SystemGraph1)] == RDF.iri(EX.NewName)
      assert Service.graph_by_name(updated, EX.NewName) == graph
    end

    test "adds :default mapping", %{service: service, data_graphs: [_, graph2]} do
      service = %{service | graph_names: %{}, graph_names_by_id: %{}}

      assert {:ok, updated} = Service.Type.add_graph_name(service, :default, EX.DataGraph2)

      assert updated.graph_names[:default] == RDF.iri(EX.DataGraph2)
      assert updated.graph_names_by_id[RDF.iri(EX.DataGraph2)] == :default
      assert Service.default_graph(updated) == graph2
    end

    test "returns error for duplicate graph name", %{service: service} do
      assert Service.Type.add_graph_name(service, EX.WorkingGraph1Name, EX.SystemGraph1) ==
               {:error, %DCATR.DuplicateGraphNameError{name: RDF.iri(EX.WorkingGraph1Name)}}
    end

    test "returns error for non-existent graph", %{service: service} do
      assert Service.Type.add_graph_name(service, EX.NewName, EX.NonExistent) ==
               {:error, %DCATR.GraphNotFoundError{graph_id: RDF.iri(EX.NonExistent)}}
    end

    test "blank node stability", %{service: service, data_graphs: [_, graph2]} do
      service = %{service | graph_names: %{}, graph_names_by_id: %{}}

      assert {:ok, updated} =
               Service.Type.add_graph_name(service, RDF.bnode("test"), EX.DataGraph2)

      assert updated.graph_names[RDF.bnode("test")] == RDF.iri(EX.DataGraph2)
      assert Service.graph_by_name(updated, RDF.bnode("test")) == graph2
    end
  end
end
