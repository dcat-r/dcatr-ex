defmodule DCATR.ManifestTest do
  use DCATR.Case

  doctest DCATR.Manifest

  alias DCATR.Manifest
  alias DCATR.{Service, Repository, RepositoryManifestGraph, Dataset}

  import RDF.Sigils

  describe "env/1" do
    test "returns configured environment" do
      assert Manifest.env(env: :prod) == :prod
      assert Manifest.env(env: :dev) == :dev
      assert Manifest.env(env: :test) == :test
    end

    test "accepts string environments" do
      assert Manifest.env(env: "PROD") == :prod
      assert Manifest.env(env: "prod") == :prod
    end

    test "reads from DCATR_ENV" do
      System.put_env("DCATR_ENV", "prod")
      assert Manifest.env() == :prod
      System.delete_env("DCATR_ENV")
    end

    test "falls back to MIX_ENV" do
      System.put_env("MIX_ENV", "dev")
      assert Manifest.env() == :dev
      System.delete_env("MIX_ENV")
    end

    test "raises on invalid environment" do
      assert_raise RuntimeError, ~r/Invalid environment/, fn ->
        Manifest.env(env: :invalid)
      end
    end
  end

  describe "with test manifest" do
    setup do
      [load_path: TestData.manifest("flat_dir")]
    end

    test "service/0", %{load_path: load_path} do
      assert {:ok,
              %Service{
                repository: %Repository{
                  dataset: %Dataset{}
                }
              }} = Manifest.service(load_path: load_path)
    end

    test "repository/0", %{load_path: load_path} do
      assert {:ok, %Repository{dataset: %Dataset{}}} =
               Manifest.repository(load_path: load_path)
    end

    test "dataset/0", %{load_path: load_path} do
      assert {:ok,
              %Dataset{
                __additional_statements__: %{
                  ~I<http://purl.org/dc/terms/title> => %{~L"test dataset" => nil}
                }
              }} = Manifest.dataset(load_path: load_path)
    end
  end

  describe "with default manifest" do
    test "service/0" do
      assert {:ok,
              %Service{
                repository: %Repository{
                  dataset: %Dataset{},
                  manifest_graph: %RepositoryManifestGraph{}
                }
              }} = Manifest.service()
    end

    test "repository/0" do
      assert {:ok, %Repository{dataset: %Dataset{}}} = Manifest.repository()
    end

    test "dataset/0" do
      assert {:ok,
              %Dataset{
                __additional_statements__: %{
                  ~I<http://purl.org/dc/terms/title> => %{~L"test dataset" => nil}
                }
              }} = Manifest.dataset()
    end
  end

  describe "service_manifest_graph/1" do
    test "returns graph with well-known name when using default IDs" do
      {:ok, manifest} = Manifest.manifest(load_path: TestData.manifest("flat_dir"))

      graph = Manifest.service_manifest_graph(manifest)

      assert graph.name == ~B<service-manifest>
      assert RDF.Graph.include?(graph, {EX.Service, RDF.type(), DCATR.Service})
    end

    test "returns graph with custom name from manifest specification" do
      {:ok, manifest} =
        Manifest.manifest(load_path: TestData.manifest("custom_service_graph_name.trig"))

      graph = Manifest.service_manifest_graph(manifest)

      assert graph.name == RDF.iri(EX.ServiceManifest)
      assert RDF.Graph.include?(graph, {EX.Service, RDF.type(), DCATR.Service})
    end

    test "works with dataset during loading" do
      {:ok, dataset} = DCATR.Manifest.load_dataset(load_path: TestData.manifest("flat_dir"))

      assert {:ok, graph} = Manifest.service_manifest_graph(dataset)

      assert graph.name == ~B<service-manifest>
      assert RDF.Graph.include?(graph, {EX.Service, RDF.type(), DCATR.Service})
    end

    test "returns nil when manifest graph is missing" do
      dataset = RDF.Dataset.new()

      assert Manifest.service_manifest_graph(dataset) ==
               {:error, %DCATR.ManifestError{data: dataset, reason: :no_service_graph}}
    end
  end

  describe "repository_manifest_graph/1" do
    test "returns graph with custom name when ID is specified" do
      {:ok, manifest} = Manifest.manifest(load_path: TestData.manifest("flat_dir"))

      graph = Manifest.repository_manifest_graph(manifest)

      assert graph.name == RDF.iri(EX.RepositoryManifestGraph)
      assert RDF.Graph.include?(graph, {EX.Repository, RDF.type(), DCATR.Repository})
    end

    test "returns graph with custom name from manifest specification" do
      {:ok, manifest} =
        Manifest.manifest(load_path: TestData.manifest("custom_service_graph_name.trig"))

      graph = Manifest.repository_manifest_graph(manifest)

      assert graph.name == RDF.iri(EX.RepositoryManifest)
      assert RDF.Graph.include?(graph, {EX.Repository, RDF.type(), DCATR.Repository})
    end

    test "works with dataset during loading" do
      {:ok, dataset} = DCATR.Manifest.load_dataset(load_path: TestData.manifest("flat_dir"))

      assert {:ok, graph} = Manifest.repository_manifest_graph(dataset)

      assert graph.name == ~B<repository-manifest>
      assert RDF.Graph.include?(graph, {EX.Repository, RDF.type(), DCATR.Repository})
    end

    test "returns nil when manifest graph is missing" do
      dataset = RDF.Dataset.new()

      assert Manifest.repository_manifest_graph(dataset) ==
               {:error, %DCATR.ManifestError{data: dataset, reason: :no_repository_graph}}
    end
  end
end
