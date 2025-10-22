defmodule DCATR.Integration.ExamplesTest do
  use DCATR.Case

  alias DCATR.{Manifest, Service, Repository, Dataset, DataGraph}

  import RDF.Sigils

  test "Scenario 2: Global Graph Names" do
    example_opts = [load_path: "examples/scenario2-global-graph-names.trig"]

    assert %Service{__id__: ~I<http://example.org/myService>} =
             service = Manifest.service!(example_opts)

    assert %Repository{__id__: ~I<http://example.org/myRepository>} =
             Manifest.repository!(example_opts)

    assert %Dataset{__id__: ~I<http://example.org/myDataset>} =
             Manifest.dataset!(example_opts)

    assert Manifest.dataset!(example_opts)
           |> Dataset.graphs()
           |> Enum.sort_by(& &1.__id__) == [
             %DataGraph{
               __id__: ~I<http://example.org/customers-graph>,
               __additional_statements__: %{
                 ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                   ~I<https://w3id.org/dcat-r#DataGraph> => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#description> => %{
                   ~L"Customer profiles and relationship data" => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#title> => %{~L"Customer Data Graph" => nil}
               }
             },
             %DataGraph{
               __id__: ~I<http://example.org/products-graph>,
               __additional_statements__: %{
                 ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                   ~I<https://w3id.org/dcat-r#DataGraph> => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#description> => %{
                   ~L"Contains the complete product catalog with pricing and availability" => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#title> => %{~L"Product Catalog Graph" => nil}
               }
             }
           ]

    assert Service.graph_name_mapping(service) == %{}

    assert Service.default_graph(service) == nil

    assert %DataGraph{__id__: ~I<http://example.org/products-graph>} =
             Service.graph_by_id(service, ~I<http://example.org/products-graph>)

    assert %DataGraph{__id__: ~I<http://example.org/customers-graph>} =
             Service.graph_by_id(service, ~I<http://example.org/customers-graph>)

    manifest_graph = Repository.graph(Manifest.repository!(example_opts), :repository_manifest)

    assert %DCATR.RepositoryManifestGraph{__id__: ~I<http://example.org/repository-manifest>} =
             manifest_graph
  end

  test "Scenario 3: Local Graph Names" do
    example_opts = [load_path: "examples/scenario3-local-graph-names.trig"]

    # Load via cached API
    service = Manifest.service!(example_opts)

    # Verify Service structure
    assert %Service{__id__: ~I<http://example.org/myService>} = service

    # Verify Repository
    assert %Repository{__id__: ~I<http://example.org/myRepository>} =
             Manifest.repository!(example_opts)

    # Verify Dataset
    assert %Dataset{__id__: ~I<http://example.org/myDataset>} = Manifest.dataset!(example_opts)

    # Verify DataGraphs (via Dataset.graphs/1) - using canonical URIs
    assert Manifest.dataset!(example_opts) |> Dataset.graphs() |> Enum.sort_by(& &1.__id__) == [
             %DataGraph{
               __id__: ~I<http://example.org/catalog-2024-09>,
               __additional_statements__: %{
                 ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                   ~I<https://w3id.org/dcat-r#DataGraph> => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#description> => %{
                   ~L"Product catalog snapshot from September 2024" => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#issued> => %{
                   RDF.XSD.Date.new("2024-09-01") => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#title> => %{
                   ~L"September 2024 Product Catalog" => nil
                 }
               }
             },
             %DataGraph{
               __id__: ~I<http://example.org/users-2024-09>,
               __additional_statements__: %{
                 ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                   ~I<https://w3id.org/dcat-r#DataGraph> => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#description> => %{
                   ~L"Active user profiles as of September 2024" => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#issued> => %{
                   RDF.XSD.Date.new("2024-09-01") => nil
                 },
                 ~I<http://www.w3.org/ns/dcat#title> => %{~L"September 2024 User Data" => nil}
               }
             }
           ]

    # Verify local graph name mappings
    assert Service.graph_name_mapping(service) == %{
             ~I<http://localhost/graphs/products> => ~I<http://example.org/catalog-2024-09>,
             ~I<http://localhost/graphs/customers> => ~I<http://example.org/users-2024-09>,
             :default => ~I<http://example.org/catalog-2024-09>
           }

    # Verify default graph
    assert %DataGraph{__id__: ~I<http://example.org/catalog-2024-09>} =
             Service.default_graph(service)

    # Verify graph access by canonical ID
    assert %DataGraph{__id__: ~I<http://example.org/catalog-2024-09>} =
             Service.graph_by_id(service, ~I<http://example.org/catalog-2024-09>)

    assert %DataGraph{__id__: ~I<http://example.org/users-2024-09>} =
             Service.graph_by_id(service, ~I<http://example.org/users-2024-09>)

    # Verify graph access by local name
    assert %DataGraph{__id__: ~I<http://example.org/catalog-2024-09>} =
             Service.graph_by_name(service, ~I<http://localhost/graphs/products>)

    assert %DataGraph{__id__: ~I<http://example.org/users-2024-09>} =
             Service.graph_by_name(service, ~I<http://localhost/graphs/customers>)

    # Verify graph access by :default
    assert %DataGraph{__id__: ~I<http://example.org/catalog-2024-09>} =
             Service.graph_by_name(service, :default)

    # Verify repository manifest graph
    manifest_graph = Repository.graph(Manifest.repository!(example_opts), :repository_manifest)

    assert %DCATR.RepositoryManifestGraph{__id__: ~I<http://example.org/repository-manifest>} =
             manifest_graph
  end

  test "Scenario 4: Mixed Graph Names" do
    example_opts = [load_path: "examples/scenario4-mixed-graph-names.trig"]

    assert %Service{__id__: ~I<http://example.org/myService>} =
             service = Manifest.service!(example_opts)

    assert %Repository{__id__: ~I<http://example.org/myRepository>} =
             Manifest.repository!(example_opts)

    assert %Dataset{__id__: ~I<http://example.org/myDataset>} = Manifest.dataset!(example_opts)

    # Verify all 4 DataGraphs (sorted by ID for consistent ordering)
    data_graphs = Manifest.dataset!(example_opts) |> Dataset.graphs() |> Enum.sort_by(& &1.__id__)
    assert length(data_graphs) == 4

    # Verify local graph name mappings (only for 2 graphs, plus default)
    assert Service.graph_name_mapping(service) == %{
             ~I<http://localhost/graphs/transactions> =>
               ~I<http://example.org/transactions-2024-09>,
             ~I<http://localhost/graphs/dashboard> => ~I<http://example.org/analytics-2024-09>,
             :default => ~I<http://example.org/repository-manifest>
           }

    # Verify default graph is the repository manifest (a SystemGraph, not a DataGraph)
    assert %DCATR.RepositoryManifestGraph{__id__: ~I<http://example.org/repository-manifest>} =
             Service.default_graph(service)

    # Verify graph access by canonical ID (all graphs accessible)
    assert %DataGraph{__id__: ~I<http://example.org/core-ontology>} =
             Service.graph_by_id(service, ~I<http://example.org/core-ontology>)

    assert %DataGraph{__id__: ~I<http://example.org/transactions-2024-09>} =
             Service.graph_by_id(service, ~I<http://example.org/transactions-2024-09>)

    assert %DataGraph{__id__: ~I<http://example.org/analytics-2024-09>} =
             Service.graph_by_id(service, ~I<http://example.org/analytics-2024-09>)

    assert %DataGraph{__id__: ~I<http://example.org/reference-data>} =
             Service.graph_by_id(service, ~I<http://example.org/reference-data>)

    # Verify graph access by local name (only for graphs with local names)
    assert %DataGraph{__id__: ~I<http://example.org/transactions-2024-09>} =
             Service.graph_by_name(service, ~I<http://localhost/graphs/transactions>)

    assert %DataGraph{__id__: ~I<http://example.org/analytics-2024-09>} =
             Service.graph_by_name(service, ~I<http://localhost/graphs/dashboard>)

    # Graphs without local names return nil when accessed by non-existent local name
    assert Service.graph_by_name(service, ~I<http://localhost/graphs/ontology>) == nil

    # Verify SystemGraph (history-graph) is accessible
    assert [%DCATR.SystemGraph{__id__: ~I<http://example.org/history-graph>}] =
             Repository.graphs(Manifest.repository!(example_opts), type: :system)

    # Verify repository manifest graph
    manifest_graph = Repository.graph(Manifest.repository!(example_opts), :repository_manifest)

    assert %DCATR.RepositoryManifestGraph{__id__: ~I<http://example.org/repository-manifest>} =
             manifest_graph
  end
end
