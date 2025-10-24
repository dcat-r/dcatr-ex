defmodule DCATR.Manifest.GraphExpansionTest do
  use DCATR.Case

  doctest DCATR.Manifest.GraphExpansion

  alias DCATR.Manifest.GraphExpansion
  alias DCATR.Manifest.Loader

  @moduletag :manifest_expansion

  @alice EX.Alice
         |> RDF.type(FOAF.Agent)
         |> FOAF.name("Alice Smith")
         |> PROV.actedOnBehalfOf(EX.Org)
         |> EX.otherProperty(EX.Other)

  @org EX.Org
       |> RDF.type(PROV.Organization)
       |> FOAF.name("Example Org")
       |> EX.location(EX.Berlin)

  @location EX.Berlin
            |> RDF.type(EX.Location)
            |> FOAF.name("Berlin")

  @other EX.Other
         |> RDF.type(EX.OtherType)
         |> FOAF.name("Other Resource")

  @ignored_statements {EX.Unrelated, EX.p(), EX.O}

  @example_graph RDF.graph([@alice, @org, @location, @other, @ignored_statements])

  describe "expand/3" do
    test "depth 0 disables expansion" do
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 0) == manifest_graph
    end

    test "depth 1 expands direct references" do
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 1) ==
               RDF.graph([manifest_graph, @alice])
    end

    test "depth 2 expands direct references" do
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 2) ==
               RDF.graph([manifest_graph, @alice, @org, @other])
    end

    test "depth 3 expands transitive references" do
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 3) ==
               RDF.graph([manifest_graph, @alice, @org, @other, @location])
    end

    test "blank nodes always expanded with unlimited depth" do
      org_bnode = ~B<org>
      location_bnode = ~B<location>

      default_graph =
        RDF.graph([
          {EX.Alice, PROV.actedOnBehalfOf(), org_bnode},
          org_bnode
          |> RDF.type(PROV.Organization)
          |> FOAF.name("Example Org")
          |> EX.location(location_bnode),
          location_bnode
          |> RDF.type(EX.Location)
          |> FOAF.name("Berlin")
        ])

      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, default_graph) ==
               RDF.graph([manifest_graph, default_graph])
    end

    test "cycles handled without infinite loops" do
      default_graph =
        RDF.graph([
          {EX.A, EX.references(), EX.B},
          {EX.B, EX.references(), EX.A},
          {EX.A, FOAF.name(), "Resource A"},
          {EX.B, FOAF.name(), "Resource B"}
        ])

      manifest_graph = RDF.graph({EX.Service, EX.uses(), EX.A})

      assert GraphExpansion.expand(manifest_graph, default_graph, depth: 5) ==
               RDF.graph([manifest_graph, default_graph])
    end

    test "empty default graph returns manifest unchanged" do
      default_graph = RDF.graph()
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, default_graph, depth: 1) == manifest_graph
      assert GraphExpansion.expand(manifest_graph, default_graph, depth: 3) == manifest_graph
    end

    test "manifest with no object IRIs returns unchanged" do
      manifest_graph =
        EX.Service
        |> RDF.type(EX.ServiceType)
        |> FOAF.name("My Service")
        |> RDF.graph()

      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 1) == manifest_graph
      assert GraphExpansion.expand(manifest_graph, @example_graph, depth: 3) == manifest_graph
    end

    test "predicate filtering restricts which links to follow" do
      manifest_graph = RDF.graph({EX.Service, PROV.wasAttributedTo(), EX.Alice})

      assert GraphExpansion.expand(manifest_graph, @example_graph,
               depth: 2,
               predicates: [PROV.actedOnBehalfOf()]
             ) ==
               RDF.graph([manifest_graph, @alice, @org])
    end
  end

  describe "expand_dataset/2" do
    test "expands both service and repository manifest graphs" do
      dataset =
        RDF.dataset()
        |> RDF.Dataset.add(@example_graph)
        |> RDF.Dataset.add({EX.Service, PROV.wasAttributedTo(), EX.Alice},
          graph: Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add({EX.Repository, DCTerms.creator(), EX.Alice},
          graph: Loader.repository_manifest_graph_name()
        )
        |> RDF.Dataset.add({EX.Data, EX.p(), EX.O}, graph: EX.DataGraph)

      assert GraphExpansion.expand_dataset(dataset, depth: 2) ==
               {:ok,
                RDF.dataset()
                |> RDF.Dataset.add(@example_graph)
                |> RDF.Dataset.add(
                  [{EX.Service, PROV.wasAttributedTo(), EX.Alice}, @alice, @org, @other],
                  graph: Loader.service_manifest_graph_name()
                )
                |> RDF.Dataset.add(
                  [{EX.Repository, DCTerms.creator(), EX.Alice}, @alice, @org, @other],
                  graph: Loader.repository_manifest_graph_name()
                )
                |> RDF.Dataset.add({EX.Data, EX.p(), EX.O}, graph: EX.DataGraph)}
    end

    test "handles missing default graph gracefully" do
      dataset =
        RDF.dataset()
        |> RDF.Dataset.add({EX.Service, PROV.wasAttributedTo(), EX.Alice},
          graph: Loader.service_manifest_graph_name()
        )
        |> RDF.Dataset.add({EX.Repository, DCTerms.creator(), EX.Alice},
          graph: Loader.repository_manifest_graph_name()
        )

      assert GraphExpansion.expand_dataset(dataset) == {:ok, dataset}
    end
  end
end
