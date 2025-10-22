defmodule DCATR.RepositoryTest do
  use DCATR.Case

  doctest DCATR.Repository

  alias DCATR.Repository

  describe "build/1,2" do
    test "with required dataset" do
      dataset = dataset()

      assert Repository.build(EX.Repository1, dataset: dataset) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: dataset,
                  manifest_graph: nil,
                  system_graphs: []
                }}
    end

    test "with all properties" do
      dataset = dataset()
      manifest_graph = repository_manifest_graph()
      system_graph1 = system_graph()
      system_graph2 = system_graph()

      assert Repository.build(EX.Repository1,
               dataset: dataset,
               manifest_graph: manifest_graph,
               system_graphs: [system_graph1, system_graph2]
             ) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: dataset,
                  manifest_graph: manifest_graph,
                  system_graphs: [system_graph1, system_graph2]
                }}
    end
  end

  describe "load/2" do
    test "minimal repository" do
      assert EX.Repository1
             |> DCATR.repositoryDataset(EX.Dataset1)
             |> DCATR.repositoryManifestGraph(EX.RepositoryManifest)
             |> RDF.graph()
             |> Repository.load(EX.Repository1) ==
               {:ok,
                Repository.build!(EX.Repository1,
                  dataset: dataset(id: EX.Dataset1),
                  manifest_graph: repository_manifest_graph(id: EX.RepositoryManifest)
                )}
    end

    test "repository with all properties" do
      assert RDF.graph([
               {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
               {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
               {EX.Dataset1, RDF.type(), DCATR.Dataset},
               {EX.Dataset1, DCATR.dataGraph(), [EX.DataGraph1, EX.DataGraph2]},
               {EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph},
               {EX.SystemGraph1, RDF.type(), DCATR.SystemGraph},
               {EX.SystemGraph2, RDF.type(), DCATR.SystemGraph},
               {EX.Repository1, RDF.type(), DCATR.Repository},
               {EX.Repository1, DCATR.repositoryDataset(), EX.Dataset1},
               {EX.Repository1, DCATR.repositoryManifestGraph(), EX.RepositoryManifest},
               {EX.Repository1, DCATR.repositorySystemGraph(), [EX.SystemGraph1, EX.SystemGraph2]}
             ])
             |> Repository.load(EX.Repository1, depth: 99) == {:ok, example_repository()}
    end
  end

  test "Grax.to_rdf/1" do
    dataset = dataset()
    manifest_graph = repository_manifest_graph()
    system_graph = system_graph()

    repo =
      repository(
        dataset: dataset,
        manifest_graph: manifest_graph,
        system_graphs: [system_graph]
      )

    rdf = Grax.to_rdf!(repo)

    assert RDF.Graph.include?(rdf, {repo.__id__, RDF.type(), DCATR.Repository})
    assert RDF.Graph.include?(rdf, {repo.__id__, DCATR.repositoryDataset(), dataset.__id__})

    assert RDF.Graph.include?(
             rdf,
             {repo.__id__, DCATR.repositoryManifestGraph(), manifest_graph.__id__}
           )

    assert RDF.Graph.include?(
             rdf,
             {repo.__id__, DCATR.repositorySystemGraph(), system_graph.__id__}
           )
  end

  describe "graph/2" do
    setup :example_repository_scenario

    test "returns manifest graph with :repository_manifest and :repo_manifest selector", %{
      repo: repo,
      repo_manifest: manifest
    } do
      assert Repository.graph(repo, :repository_manifest) == manifest
      assert Repository.graph(repo, :repo_manifest) == manifest
    end

    test "returns system graph by ID", %{
      repo: repo,
      system_graphs: [system_graph1, system_graph2]
    } do
      assert Repository.graph(repo, system_graph1.__id__) == system_graph1
      assert Repository.graph(repo, EX.SystemGraph1) == system_graph1
      assert Repository.graph(repo, system_graph2.__id__) == system_graph2
      assert Repository.graph(repo, EX.SystemGraph2) == system_graph2
    end

    test "returns graph by ID", %{
      repo: repo,
      repo_manifest: repo_manifest,
      data_graphs: [data_graph1 | _]
    } do
      assert Repository.graph(repo, repo_manifest.__id__) == repo_manifest
      assert Repository.graph(repo, EX.RepositoryManifest) == repo_manifest
      assert Repository.graph(repo, data_graph1.__id__) == data_graph1
      assert Repository.graph(repo, EX.DataGraph1) == data_graph1
    end

    test "returns nil for non-existent graph", %{repo: repo} do
      assert Repository.graph(repo, EX.NonExistent) == nil
    end
  end

  test "resolve_graph_selector/2" do
    repo = example_repository()

    assert Repository.resolve_graph_selector(repo, :repository_manifest) == repo.manifest_graph
    assert Repository.resolve_graph_selector(repo, :repo_manifest) == repo.manifest_graph
    assert Repository.resolve_graph_selector(repo, :unknown_selector) == nil
  end

  describe "graphs/2" do
    setup :example_repository_scenario

    test "returns all graphs without options", %{
      repo: repo,
      data_graphs: [data_graph1, data_graph2],
      repo_manifest: repo_manifest,
      system_graphs: [system_graph1, system_graph2]
    } do
      graphs = Repository.graphs(repo)
      assert length(graphs) == 5
      assert data_graph1 in graphs
      assert data_graph2 in graphs
      assert repo_manifest in graphs
      assert system_graph1 in graphs
      assert system_graph2 in graphs
    end

    test "filters by type :data", %{repo: repo, data_graphs: data_graphs} do
      assert Repository.graphs(repo, type: :data) == data_graphs
    end

    test "filters by type :system", %{repo: repo, system_graphs: system_graphs} do
      assert Repository.graphs(repo, type: :system) == system_graphs
    end

    test "filters by type :manifest", %{repo: repo, repo_manifest: repo_manifest} do
      assert Repository.graphs(repo, type: :manifest) == [repo_manifest]
    end

    test "returns empty list for unknown type filter", %{repo: repo} do
      assert Repository.graphs(repo, type: :unknown) == []
    end

    test "filters by multiple types as list", %{
      repo: repo,
      data_graphs: [data_graph1, data_graph2],
      system_graphs: [system_graph1, system_graph2],
      repo_manifest: repo_manifest
    } do
      graphs = Repository.graphs(repo, type: [:data, :system])
      assert length(graphs) == 4
      assert data_graph1 in graphs
      assert data_graph2 in graphs
      assert system_graph1 in graphs
      assert system_graph2 in graphs
      refute repo_manifest in graphs
    end

    test "filters by multiple types including manifest", %{
      repo: repo,
      repo_manifest: repo_manifest,
      system_graphs: [system_graph1, system_graph2]
    } do
      graphs = Repository.graphs(repo, type: [:manifest, :system])
      assert length(graphs) == 3
      assert repo_manifest in graphs
      assert system_graph1 in graphs
      assert system_graph2 in graphs
    end

    test "handles empty list of types", %{repo: repo} do
      assert Repository.graphs(repo, type: []) == []
    end

    test "handles list with unknown types", %{repo: repo} do
      assert Repository.graphs(repo, type: [:unknown, :invalid]) == []
    end

    test "handles mixed valid and invalid types", %{repo: repo, repo_manifest: repo_manifest} do
      assert Repository.graphs(repo, type: [:manifest, :unknown]) == [repo_manifest]
    end
  end

  test "system_graphs/1" do
    system_graphs = example_system_graphs()

    assert repository(system_graphs: system_graphs)
           |> Repository.system_graphs() == system_graphs

    assert repository(system_graphs: []) |> Repository.system_graphs() == []
  end

  describe "has_graph?/2" do
    setup :example_repository_scenario

    test "returns true for existing graphs by ID", %{
      repo: repo,
      system_graphs: [system_graph | _]
    } do
      assert Repository.has_graph?(repo, system_graph.__id__) == true
      assert Repository.has_graph?(repo, EX.RepositoryManifest) == true
    end

    test "returns true for existing graphs by selector", %{repo: repo} do
      assert Repository.has_graph?(repo, :repository_manifest) == true
      assert Repository.has_graph?(repo, :repo_manifest) == true
    end

    test "returns false for non-existent graphs", %{repo: repo} do
      assert Repository.has_graph?(repo, EX.NonExistent) == false
    end
  end
end
