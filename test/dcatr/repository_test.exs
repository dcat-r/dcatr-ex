defmodule DCATR.RepositoryTest do
  use DCATR.Case

  doctest DCATR.Repository

  alias DCATR.Repository

  describe "new/1,2" do
    test "with required fields" do
      dataset = dataset()
      manifest_graph = repository_manifest_graph()

      assert Repository.new(EX.Repository1, dataset: dataset, manifest_graph: manifest_graph) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: dataset,
                  primary_graph: nil,
                  manifest_graph: manifest_graph,
                  system_graphs: []
                }}
    end

    test "with all properties" do
      dataset = dataset()
      manifest_graph = repository_manifest_graph()
      system_graph1 = system_graph()
      system_graph2 = system_graph()

      assert Repository.new(EX.Repository1,
               dataset: dataset,
               manifest_graph: manifest_graph,
               system_graphs: [system_graph1, system_graph2]
             ) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: dataset,
                  primary_graph: nil,
                  manifest_graph: manifest_graph,
                  system_graphs: [system_graph1, system_graph2]
                }}
    end

    test "with primary_graph only (single-graph mode)" do
      primary_graph = data_graph()
      manifest_graph = repository_manifest_graph()

      assert Repository.new(EX.Repository1,
               primary_graph: primary_graph,
               manifest_graph: manifest_graph
             ) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: nil,
                  primary_graph: primary_graph,
                  manifest_graph: manifest_graph,
                  system_graphs: []
                }}
    end

    test "with both dataset and primary_graph (multi-graph with primary)" do
      dataset = dataset()
      primary_graph = List.first(dataset.graphs)
      manifest_graph = repository_manifest_graph()

      assert Repository.new(EX.Repository1,
               dataset: dataset,
               primary_graph: primary_graph,
               manifest_graph: manifest_graph
             ) ==
               {:ok,
                %Repository{
                  __id__: RDF.iri(EX.Repository1),
                  dataset: dataset,
                  primary_graph: primary_graph,
                  manifest_graph: manifest_graph,
                  system_graphs: []
                }}
    end

    test "rejects primary_graph not in dataset when both present" do
      dataset = dataset()
      orphan_primary = data_graph()
      manifest_graph = repository_manifest_graph()

      assert {:error,
              %Grax.ValidationError{
                errors: [
                  on_validate:
                    "primary_graph must be one of the dataset's graphs when both are present"
                ]
              }} =
               Repository.new(EX.Repository1,
                 dataset: dataset,
                 primary_graph: orphan_primary,
                 manifest_graph: manifest_graph
               )
    end

    test "requires at least one of dataset or primary_graph" do
      manifest_graph = repository_manifest_graph()

      assert {:error,
              %Grax.ValidationError{
                errors: [on_validate: "at least one of dataset or primary_graph required"]
              }} =
               Repository.new(EX.Repo, manifest_graph: manifest_graph)
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
                Repository.new!(EX.Repository1,
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

    test "repository with primary_graph only (single-graph mode)" do
      graph =
        RDF.graph([
          {EX.PrimaryGraph, RDF.type(), DCATR.DataGraph},
          {EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph},
          {EX.SingleGraphRepo, RDF.type(), DCATR.Repository},
          {EX.SingleGraphRepo, DCATR.repositoryPrimaryGraph(), EX.PrimaryGraph},
          {EX.SingleGraphRepo, DCATR.repositoryManifestGraph(), EX.RepositoryManifest}
        ])

      assert Repository.load(graph, EX.SingleGraphRepo, depth: 1) ==
               {:ok,
                Repository.new!(EX.SingleGraphRepo,
                  primary_graph: data_graph(id: EX.PrimaryGraph),
                  manifest_graph: repository_manifest_graph(id: EX.RepositoryManifest)
                )}
    end

    test "repository with both dataset and primary_graph (multi-graph with primary)" do
      graph =
        RDF.graph([
          {EX.DataGraph1, RDF.type(), DCATR.DataGraph},
          {EX.DataGraph2, RDF.type(), DCATR.DataGraph},
          {EX.Dataset1, RDF.type(), DCATR.Dataset},
          {EX.Dataset1, DCATR.dataGraph(), [EX.DataGraph1, EX.DataGraph2]},
          {EX.RepositoryManifest, RDF.type(), DCATR.RepositoryManifestGraph},
          {EX.MultiGraphRepo, RDF.type(), DCATR.Repository},
          {EX.MultiGraphRepo, DCATR.repositoryDataset(), EX.Dataset1},
          {EX.MultiGraphRepo, DCATR.repositoryPrimaryGraph(), EX.DataGraph1},
          {EX.MultiGraphRepo, DCATR.repositoryManifestGraph(), EX.RepositoryManifest}
        ])

      {:ok, loaded_repo} = Repository.load(graph, EX.MultiGraphRepo, depth: 2)

      assert loaded_repo.primary_graph.__id__ == RDF.iri(EX.DataGraph1)
      assert loaded_repo.dataset.__id__ == RDF.iri(EX.Dataset1)
      assert length(loaded_repo.dataset.graphs) == 2
    end
  end

  describe "Grax.to_rdf/1" do
    test "repository with dataset" do
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

    test "repository with primary_graph only (single-graph mode)" do
      primary_graph = data_graph()

      repo = single_graph_repository(id: EX.Repo, primary_graph: primary_graph)

      rdf = Grax.to_rdf!(repo)

      assert RDF.Graph.include?(rdf, {repo.__id__, RDF.type(), DCATR.Repository})

      assert RDF.Graph.include?(
               rdf,
               {repo.__id__, DCATR.repositoryPrimaryGraph(), primary_graph.__id__}
             )

      refute RDF.Graph.include?(rdf, {repo.__id__, DCATR.repositoryDataset(), nil})
    end

    test "repository with both dataset and primary_graph (multi-graph with primary)" do
      graph1 = data_graph()
      graph2 = data_graph()
      dataset = dataset(graphs: [graph1, graph2])
      primary_graph = graph1

      repo =
        multi_graph_with_primary_repository(
          id: EX.Repo,
          dataset: dataset,
          primary_graph: primary_graph
        )

      rdf = Grax.to_rdf!(repo)

      assert RDF.Graph.include?(rdf, {repo.__id__, RDF.type(), DCATR.Repository})
      assert RDF.Graph.include?(rdf, {repo.__id__, DCATR.repositoryDataset(), dataset.__id__})

      assert RDF.Graph.include?(
               rdf,
               {repo.__id__, DCATR.repositoryPrimaryGraph(), primary_graph.__id__}
             )
    end
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

    test "returns primary graph via :primary selector (single-graph mode)" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.graph(repo, :primary) == primary_graph
    end

    test "returns primary graph via :primary selector (multi-graph mode)" do
      primary_graph = data_graph()
      other_graph = data_graph()
      ds = dataset(graphs: [primary_graph, other_graph])
      repo = multi_graph_with_primary_repository(dataset: ds, primary_graph: primary_graph)

      assert Repository.graph(repo, :primary) == primary_graph
    end

    test "returns nil for :primary when no primary_graph", %{repo: repo} do
      assert Repository.graph(repo, :primary) == nil
    end

    test "returns primary graph by ID in single-graph mode" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.graph(repo, primary_graph.__id__) == primary_graph
    end

    test "returns nil for non-existent ID in single-graph mode" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.graph(repo, EX.NonExistent) == nil
    end

    test "returns primary graph by ID in dual-use mode" do
      primary_graph = data_graph()

      repo =
        multi_graph_with_primary_repository(
          dataset: dataset(graphs: [primary_graph, data_graph()]),
          primary_graph: primary_graph
        )

      assert Repository.graph(repo, primary_graph.__id__) == primary_graph
    end
  end

  describe "resolve_graph_selector/2" do
    test "resolves :repository_manifest and :repo_manifest" do
      repo = example_repository()

      assert Repository.resolve_graph_selector(repo, :repository_manifest) == repo.manifest_graph
      assert Repository.resolve_graph_selector(repo, :repo_manifest) == repo.manifest_graph
    end

    test "resolves :primary when primary_graph is present" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.resolve_graph_selector(repo, :primary) == primary_graph
    end

    test "returns nil for :primary when primary_graph is nil" do
      assert Repository.resolve_graph_selector(example_repository(), :primary) == nil
    end

    test "returns :undefined for unknown selectors" do
      assert Repository.resolve_graph_selector(example_repository(), :unknown_selector) ==
               :undefined
    end
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

    test "returns all graphs in single-graph mode" do
      primary_graph = data_graph()
      system_graph = system_graph()
      repo = single_graph_repository(primary_graph: primary_graph, system_graphs: [system_graph])

      graphs = Repository.graphs(repo)
      assert length(graphs) == 3
      assert repo.manifest_graph in graphs
      assert primary_graph in graphs
      assert system_graph in graphs
    end

    test "returns no duplicates in dual-use mode" do
      primary_graph = data_graph()
      other_graph = data_graph()
      ds = dataset(graphs: [primary_graph, other_graph])
      repo = multi_graph_with_primary_repository(dataset: ds, primary_graph: primary_graph)

      graphs = Repository.graphs(repo)
      assert length(graphs) == 3
      assert repo.manifest_graph in graphs
      assert primary_graph in graphs
      assert other_graph in graphs
      assert Enum.count(graphs, &(&1.__id__ == primary_graph.__id__)) == 1
    end

    test "filters by type :data in single-graph mode" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.graphs(repo, type: :data) == [primary_graph]
    end

    test "filters by type :data in dual-use mode without duplicates" do
      primary_graph = data_graph()
      other_graph = data_graph()
      ds = dataset(graphs: [primary_graph, other_graph])
      repo = multi_graph_with_primary_repository(dataset: ds, primary_graph: primary_graph)

      data_graphs = Repository.graphs(repo, type: :data)
      assert length(data_graphs) == 2
      assert primary_graph in data_graphs
      assert other_graph in data_graphs
      assert Enum.count(data_graphs, &(&1.__id__ == primary_graph.__id__)) == 1
    end
  end

  test "system_graphs/1" do
    system_graphs = example_system_graphs()

    assert repository(system_graphs: system_graphs)
           |> Repository.system_graphs() == system_graphs

    assert repository(system_graphs: []) |> Repository.system_graphs() == []
  end

  describe "primary_graph/1" do
    test "returns primary graph in single-graph mode" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.primary_graph(repo) == primary_graph
    end

    test "returns primary graph in multi-graph mode" do
      primary_graph = data_graph()
      other_graph = data_graph()
      ds = dataset(graphs: [primary_graph, other_graph])
      repo = multi_graph_with_primary_repository(dataset: ds, primary_graph: primary_graph)

      assert Repository.primary_graph(repo) == primary_graph
    end

    test "returns nil when no primary_graph" do
      repo = example_repository()

      assert Repository.primary_graph(repo) == nil
    end
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

    test "returns true for :primary selector when primary_graph present" do
      primary_graph = data_graph()
      repo = single_graph_repository(primary_graph: primary_graph)

      assert Repository.has_graph?(repo, :primary) == true
    end

    test "returns false for :primary selector when no primary_graph", %{repo: repo} do
      assert Repository.has_graph?(repo, :primary) == false
    end

    test "returns false for non-existent graphs", %{repo: repo} do
      assert Repository.has_graph?(repo, EX.NonExistent) == false
    end
  end
end
