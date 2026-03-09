defmodule DCATR.SchemaMappingTest do
  use DCATR.Case

  alias DCATR.{Repository, Directory, Dataset, ServiceData, RepositoryManifestGraph, SystemGraph}

  describe "serialization round-trip" do
    test "Repository" do
      repo = example_repository()

      assert repo |> Grax.to_rdf!() |> Repository.load!(repo.__id__) == repo
    end

    test "Dataset" do
      dataset = example_dataset()

      assert dataset |> Grax.to_rdf!() |> Dataset.load!(dataset.__id__) == dataset
    end

    test "ServiceData" do
      service_data = example_service_data()

      assert service_data |> Grax.to_rdf!() |> ServiceData.load!(service_data.__id__) ==
               service_data
    end
  end

  describe "Directory serialization round-trip" do
    test "Repository to Directory" do
      repo = example_repository()
      rdf = Grax.to_rdf!(repo)

      {:ok, dir} = Directory.load(rdf, repo.__id__, depth: 1)

      assert [%RepositoryManifestGraph{}, %SystemGraph{}, %SystemGraph{}, %Directory{}] =
               Enum.sort(dir.members)

      member_ids = Enum.map(dir.members, & &1.__id__)

      assert repo.dataset.__id__ in member_ids
      assert repo.manifest_graph.__id__ in member_ids

      for sg <- repo.system_graphs do
        assert sg.__id__ in member_ids
      end
    end

    test "Directory to Dataset" do
      graph1 = data_graph(id: EX.Graph1)
      graph2 = data_graph(id: EX.Graph2)
      dir = directory(id: EX.Dir1, members: [graph1, graph2])
      rdf = Grax.to_rdf!(dir)

      assert {:ok, %Dataset{} = loaded} = Dataset.load(rdf, dir.__id__)

      assert Enum.sort(loaded.graphs) == [graph1, graph2]
    end
  end

  describe "schema-mapping round-trip" do
    test "Repository → Directory → Repository" do
      repo = example_repository()

      assert repo |> Directory.from!() |> Repository.from!() |> strip_additional_statements() ==
               strip_additional_statements(repo)
    end

    test "Dataset → Directory → Dataset" do
      dataset = example_dataset()

      assert dataset |> Directory.from!() |> Dataset.from!() |> strip_additional_statements() ==
               strip_additional_statements(dataset)
    end

    test "ServiceData → Directory → ServiceData" do
      service_data = example_service_data()

      assert service_data
             |> Directory.from!()
             |> ServiceData.from!()
             |> strip_additional_statements() ==
               strip_additional_statements(service_data)
    end
  end

  def strip_additional_statements(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.reduce(struct, fn
      {:__additional_statements__, _}, acc ->
        %{acc | __additional_statements__: %{}}

      {key, value}, acc when is_list(value) ->
        %{acc | key => Enum.map(value, &strip_additional_statements/1)}

      {key, %{__struct__: _} = nested}, acc ->
        %{acc | key => strip_additional_statements(nested)}

      _, acc ->
        acc
    end)
  end
end
