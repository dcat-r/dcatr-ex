defmodule DCATR.Manifest.LoaderTest do
  use DCATR.Case

  doctest DCATR.Manifest.Loader

  alias DCATR.Manifest.{Loader, LoadingError}
  alias RDF.{Graph, Dataset}
  alias DCAT.NS.DCTerms

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  describe "load/2" do
    # load/2 is tested through the manifest and cache tests.

    test "respects :manifest_id option" do
      assert {:ok, %DCATR.Manifest{} = manifest} =
               Loader.load(DCATR.Manifest,
                 load_path: TestData.manifest("flat_dir"),
                 manifest_id: EX.CustomManifest
               )

      assert manifest.__id__ == RDF.iri(EX.CustomManifest)
    end

    test "uses Application.get_env for :manifest_id when not provided" do
      with_application_env(:dcatr, :manifest_id, EX.ConfiguredManifest, fn ->
        assert {:ok, %DCATR.Manifest{} = manifest} =
                 Loader.load(DCATR.Manifest, load_path: TestData.manifest("flat_dir"))

        assert manifest.__id__ == RDF.iri(EX.ConfiguredManifest)
      end)
    end
  end

  test "base/0,1" do
    assert Loader.base() == nil

    with_application_env(:dcatr, :manifest_base, "https://configured.example.org/", fn ->
      assert Loader.base() == "https://configured.example.org/"

      assert Loader.base(base: "https://explicit.example.org/") ==
               "https://explicit.example.org/"
    end)
  end

  test "init_dataset/1" do
    assert DCATR.Manifest.Loader.init_dataset([]) == {:ok, RDF.dataset()}
  end

  describe "load_file/2" do
    test "TriG graphs contains expected triples" do
      file = TestData.manifest("trig/combined.trig")

      assert {:ok, %RDF.Dataset{} = dataset} =
               DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)

      assert RDF.Dataset.graph_names(dataset) |> Enum.sort() ==
               [~B<repository-manifest>, ~B<service-manifest>]

      assert RDF.Dataset.include?(
               dataset,
               {EX.Service, RDF.type(), DCATR.Service, ~B<service-manifest>}
             )

      assert RDF.Dataset.include?(
               dataset,
               {EX.Repository, RDF.type(), DCATR.Repository, ~B<repository-manifest>}
             )
    end

    test "classifies service.ttl into _:service-manifest graph" do
      file = TestData.manifest("flat_dir/service.ttl")
      assert {:ok, result} = DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      assert %RDF.Graph{name: ~B<service-manifest>} = result
      assert RDF.Graph.include?(result, {EX.Service, RDF.type(), DCATR.Service})
    end

    test "classifies repository.ttl into _:repository-manifest graph" do
      file = TestData.manifest("flat_dir/repository.ttl")
      assert {:ok, result} = DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      assert %RDF.Graph{name: ~B<repository-manifest>} = result
      assert RDF.Graph.include?(result, {EX.Repository, RDF.type(), DCATR.Repository})
    end

    test "classifies dataset.ttl into _:repository-manifest graph" do
      file = TestData.manifest("flat_dir/dataset.ttl")
      assert {:ok, result} = DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      assert %RDF.Graph{name: ~B<repository-manifest>} = result
      assert RDF.Graph.include?(result, {EX.Dataset, RDF.type(), DCATR.Dataset})
    end

    test "classifies service.ENV.ttl into _:service-manifest graph" do
      file = TestData.manifest("env_specific/service/service.test.ttl")
      assert {:ok, result} = DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      assert %RDF.Graph{name: ~B<service-manifest>} = result
    end

    test "classifies dataset.ENV.ttl into _:repository-manifest graph", %{tmp_dir: tmp_dir} do
      for env <- ["dev", "test", "prod"] do
        dir = Path.join(tmp_dir, "/manifest/env_specific/repository")
        File.mkdir_p!(dir)
        file = Path.join(dir, "dataset.#{env}.ttl")

        File.touch!(file)

        assert {:ok, %RDF.Graph{name: ~B<repository-manifest>}} =
                 DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      end
    end

    test "classifies other files into default graph" do
      file = TestData.manifest("flat_dir/agent.ttl")
      assert {:ok, result} = DCATR.Manifest.Loader.load_file(file, manifest_type: DCATR.Manifest)
      assert %RDF.Graph{name: nil} = result
      assert RDF.Graph.include?(result, {EX.Agent, RDF.type(), FOAF.Agent})
    end
  end

  describe "load_dataset/1" do
    test "with no config files" do
      assert Loader.load_dataset(manifest_type: DCATR.Manifest, load_path: []) ==
               {:error, %LoadingError{reason: :missing}}

      assert Loader.load_dataset(
               manifest_type: DCATR.Manifest,
               load_path: TestData.manifest("empty")
             ) ==
               {:error, %LoadingError{reason: :missing}}
    end

    test "merges multiple Turtle files into named graphs" do
      {:ok, dataset} =
        Loader.load_dataset(
          manifest_type: DCATR.Manifest,
          load_path: TestData.manifest("flat_dir")
        )

      assert %RDF.Dataset{} = dataset

      service_graph = RDF.Dataset.graph(dataset, RDF.bnode("service-manifest"))
      assert RDF.Graph.include?(service_graph, {EX.Service, RDF.type(), DCATR.Service})

      repo_graph = RDF.Dataset.graph(dataset, RDF.bnode("repository-manifest"))
      assert RDF.Graph.include?(repo_graph, {EX.Repository, RDF.type(), DCATR.Repository})

      default_graph = RDF.Dataset.default_graph(dataset)
      assert RDF.Graph.include?(default_graph, {EX.Agent, RDF.type(), FOAF.Agent})
    end

    test "with single valid TriG file" do
      assert Loader.load_dataset(
               manifest_type: DCATR.Manifest,
               load_path: TestData.manifest("single_file.trig")
             ) ==
               {:ok,
                Dataset.new([
                  EX.Service
                  |> RDF.type(DCATR.Service)
                  |> DCATR.serviceRepository(EX.Repository)
                  |> Graph.new(
                    prefixes: [dcatr: DCATR],
                    name: ~B<service-manifest>
                  ),
                  EX.Repository
                  |> RDF.type(DCATR.Repository)
                  |> DCATR.repositoryDataset(EX.Dataset)
                  |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph)
                  |> Graph.new(
                    prefixes: [dcatr: DCATR],
                    name: ~B<repository-manifest>
                  )
                ])}
    end

    test "with base" do
      assert Loader.load_dataset(
               manifest_type: DCATR.Manifest,
               load_path: TestData.manifest("base_relative.trig"),
               base: EX.__base__()
             ) ==
               {:ok,
                Dataset.new([
                  EX.Service
                  |> RDF.type(DCATR.Service)
                  |> DCATR.serviceRepository(EX.Repository)
                  |> Graph.new(
                    prefixes: [dcatr: DCATR],
                    name: ~B<service-manifest>
                  ),
                  EX.Repository
                  |> RDF.type(DCATR.Repository)
                  |> DCATR.repositoryDataset(EX.Dataset)
                  |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph)
                  |> Graph.new(
                    prefixes: [dcatr: DCATR],
                    name: ~B<repository-manifest>
                  )
                ])}
    end

    test "with invalid RDF content" do
      invalid_file = TestData.manifest("invalid.ttl")

      assert {:error, %LoadingError{reason: "Turtle scanner error " <> _, file: ^invalid_file}} =
               Loader.load_dataset(manifest_type: DCATR.Manifest, load_path: invalid_file)
    end

    test "with flat directory structure" do
      assert {:ok, %RDF.Dataset{} = dataset} =
               Loader.load_dataset(
                 manifest_type: DCATR.Manifest,
                 load_path: TestData.manifest("flat_dir")
               )

      assert RDF.Dataset.graph_count(dataset) == 3

      assert RDF.Dataset.graph(dataset, ~B<service-manifest>) ==
               EX.Service
               |> RDF.type(DCATR.Service)
               |> DCATR.serviceRepository(EX.Repository)
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms, foaf: FOAF],
                 name: ~B<service-manifest>
               )

      assert RDF.Dataset.graph(dataset, ~B<repository-manifest>) ==
               [
                 EX.Repository
                 |> RDF.type(DCATR.Repository)
                 |> DCATR.repositoryDataset(EX.Dataset)
                 |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph),
                 EX.Dataset
                 |> RDF.type(DCATR.Dataset)
                 |> DCTerms.title("test dataset")
               ]
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<repository-manifest>
               )

      assert RDF.Dataset.default_graph(dataset) ==
               EX.Agent
               |> RDF.type(FOAF.Agent)
               |> FOAF.name("Max Mustermann")
               |> FOAF.mbox(~I<mailto:max.mustermann@example.com>)
               |> Graph.new(prefixes: [foaf: FOAF])
    end

    test "with nested directory structure" do
      {:ok, dataset} =
        Loader.load_dataset(
          manifest_type: DCATR.Manifest,
          load_path: TestData.manifest("nested_dir")
        )

      assert RDF.Dataset.graph_count(dataset) == 3

      assert RDF.Dataset.graph(dataset, ~B<service-manifest>) ==
               EX.Service
               |> RDF.type(DCATR.Service)
               |> DCATR.serviceRepository(EX.Repository)
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms, foaf: FOAF],
                 name: ~B<service-manifest>
               )

      assert RDF.Dataset.graph(dataset, ~B<repository-manifest>) ==
               [
                 EX.Repository
                 |> RDF.type(DCATR.Repository)
                 |> DCATR.repositoryDataset(EX.Dataset)
                 |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph),
                 EX.Dataset
                 |> RDF.type(DCATR.Dataset)
                 |> DCTerms.title("test dataset")
               ]
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<repository-manifest>
               )

      assert RDF.Dataset.default_graph(dataset) ==
               EX.Agent
               |> RDF.type(FOAF.Agent)
               |> FOAF.name("Max Mustermann")
               |> Graph.new(prefixes: [foaf: FOAF])
    end

    test "with environment-specific configuration" do
      {:ok, test_dataset} =
        Loader.load_dataset(
          manifest_type: DCATR.Manifest,
          load_path: TestData.manifest("env_specific"),
          env: :test
        )

      assert RDF.Dataset.graph_count(test_dataset) == 3

      assert RDF.Dataset.graph(test_dataset, ~B<service-manifest>) ==
               EX.Service
               |> RDF.type(DCATR.Service)
               |> DCTerms.title("Example service")
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<service-manifest>
               )

      assert RDF.Dataset.graph(test_dataset, ~B<repository-manifest>) ==
               [
                 EX.Repository
                 |> RDF.type(DCATR.Repository)
                 |> DCATR.repositoryDataset(EX.Dataset)
                 |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph)
                 |> DCTerms.creator(EX.Agent)
                 |> DCTerms.title("test repository"),
                 EX.Dataset
                 |> RDF.type(DCATR.Dataset)
                 |> DCTerms.title("test dataset")
               ]
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<repository-manifest>
               )

      assert RDF.Dataset.default_graph(test_dataset) ==
               EX.Agent
               |> RDF.type(FOAF.Agent)
               |> FOAF.name("Max Mustermann")
               |> FOAF.mbox(~I<mailto:max.mustermann.test@example.com>)
               |> Graph.new(prefixes: [foaf: FOAF])

      {:ok, dev_dataset} =
        Loader.load_dataset(
          manifest_type: DCATR.Manifest,
          load_path: TestData.manifest("env_specific"),
          env: :dev
        )

      assert RDF.Dataset.graph(dev_dataset, ~B<service-manifest>) ==
               EX.Service
               |> RDF.type(DCATR.Service)
               |> DCTerms.title("Example service")
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<service-manifest>
               )

      assert RDF.Dataset.graph(dev_dataset, ~B<repository-manifest>) ==
               [
                 EX.Repository
                 |> RDF.type(DCATR.Repository)
                 |> DCATR.repositoryDataset(EX.Dataset)
                 |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph)
                 |> DCTerms.creator(EX.Agent)
                 |> DCTerms.title("dev repository"),
                 EX.Dataset
                 |> RDF.type(DCATR.Dataset)
                 |> DCTerms.title("dev dataset")
               ]
               |> Graph.new(
                 prefixes: [dcatr: DCATR, dcterms: DCTerms],
                 name: ~B<repository-manifest>
               )

      assert RDF.Dataset.default_graph(dev_dataset) ==
               EX.Agent
               |> RDF.type(FOAF.Agent)
               |> FOAF.name("Max Mustermann")
               |> FOAF.mbox(~I<mailto:max.mustermann@example.com>)
               |> Graph.new(prefixes: [foaf: FOAF])
    end

    test "handles {:ok, nil} return from load_file/2" do
      assert {:ok, dataset} =
               Loader.load_dataset(manifest_type: CustomManifest, files: ["ignore.ttl"])

      # CustomManifest.init_dataset adds one triple, so we expect 1 graph
      assert RDF.Dataset.graph_count(dataset) == 1
      assert RDF.Dataset.statement_count(dataset) == 1
    end
  end

  describe "load_manifest/2" do
    test "returns :no_service error when manifest has no service resource" do
      dataset = Dataset.new([Graph.new(name: ~B<service-manifest>)])
      manifest = partial_manifest(dataset: dataset, service: nil)

      assert {:error, %DCATR.ManifestError{reason: :no_service}} =
               Loader.load_manifest(manifest)
    end

    test "returns :multiple_services error when manifest has multiple services" do
      dataset =
        Dataset.new([
          [
            {EX.Service1, RDF.type(), DCATR.Service},
            {EX.Service2, RDF.type(), DCATR.Service}
          ]
          |> Graph.new(name: ~B<service-manifest>)
        ])

      manifest = partial_manifest(dataset: dataset, service: nil)

      assert {:error, %DCATR.ManifestError{reason: :multiple_services}} =
               Loader.load_manifest(manifest, [])
    end

    test "returns :multiple_service_data error when service has multiple ServiceData" do
      dataset =
        Dataset.new([
          [
            {EX.Service, RDF.type(), DCATR.Service},
            {EX.Service, DCATR.serviceLocalData(), EX.ServiceData1},
            {EX.Service, DCATR.serviceLocalData(), EX.ServiceData2}
          ]
          |> Graph.new(name: ~B<service-manifest>)
        ])

      manifest = partial_manifest(dataset: dataset, service: nil)

      assert {:error, %DCATR.ManifestError{reason: :multiple_service_data}} =
               Loader.load_manifest(manifest, [])
    end

    test "returns :multiple_service_manifest_graphs error when ServiceData has multiple manifest graphs" do
      dataset =
        Dataset.new([
          [
            {EX.Service, RDF.type(), DCATR.Service},
            {EX.Service, DCATR.serviceLocalData(), EX.ServiceData},
            {EX.ServiceData, DCATR.serviceManifestGraph(), EX.ManifestGraph1},
            {EX.ServiceData, DCATR.serviceManifestGraph(), EX.ManifestGraph2}
          ]
          |> Graph.new(name: ~B<service-manifest>)
        ])

      manifest = partial_manifest(dataset: dataset, service: nil)

      assert {:error, %DCATR.ManifestError{reason: :multiple_service_manifest_graphs}} =
               Loader.load_manifest(manifest, [])
    end

    test "returns :no_service_graph error when dataset has no service manifest graph" do
      dataset = Dataset.new([Graph.new(name: ~B<repository-manifest>)])
      manifest = partial_manifest(dataset: dataset, service: nil)

      assert {:error, %DCATR.ManifestError{reason: :no_service_graph}} =
               Loader.load_manifest(manifest, [])
    end
  end
end
