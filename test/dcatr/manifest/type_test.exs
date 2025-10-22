defmodule DCATR.Manifest.TypeTest do
  use DCATR.Case

  doctest DCATR.Manifest.Type

  test "custom manifest type" do
    assert CustomManifest.manifest!(
             load_path: TestData.manifest("single_file.trig"),
             manifest_id: RDF.bnode("manifest")
           ) ==
             %CustomManifest{
               __id__: RDF.bnode("manifest"),
               foo: "bar",
               load_path: [TestData.manifest("single_file.trig")],
               dataset:
                 RDF.Dataset.new([
                   RDF.Graph.new([
                     {EX.S1, EX.P1, EX.O1},
                     {EX.S2, EX.P2, EX.O2}
                   ]),
                   RDF.Graph.new(
                     [
                       EX.Service
                       |> RDF.type(DCATR.Service)
                       |> DCATR.serviceRepository(EX.Repository)
                       |> DCATR.serviceLocalData(RDF.bnode("service-data")),
                       RDF.bnode("service-data")
                       |> DCATR.serviceManifestGraph(RDF.bnode("service-manifest"))
                     ],
                     name: RDF.bnode("service-manifest"),
                     prefixes: [dcatr: DCATR]
                   ),
                   RDF.Graph.new(
                     [
                       EX.Repository
                       |> RDF.type(DCATR.Repository)
                       |> DCATR.repositoryDataset(EX.Dataset)
                       |> DCATR.repositoryManifestGraph(EX.RepositoryManifestGraph)
                     ],
                     name: RDF.bnode("repository-manifest"),
                     prefixes: [dcatr: DCATR]
                   )
                 ]),
               service: %DCATR.Service{
                 __id__: ~I<http://example.com/Service>,
                 repository: %DCATR.Repository{
                   __id__: ~I<http://example.com/Repository>,
                   dataset: %DCATR.Dataset{__id__: ~I<http://example.com/Dataset>},
                   manifest_graph: %DCATR.RepositoryManifestGraph{
                     __id__: ~I<http://example.com/RepositoryManifestGraph>
                   }
                 },
                 local_data: %DCATR.ServiceData{
                   __id__: RDF.bnode("service-data"),
                   manifest_graph: %DCATR.ServiceManifestGraph{
                     __id__: RDF.bnode("service-manifest")
                   }
                 }
               }
             }
  end
end
