defmodule DCATR.Manifest.GraphExpansion do
  @moduledoc """
  Manifest Graph Expansion (MGE).

  Automatically expands referenced resources from a default graph into
  manifest graphs, enabling shared resource definitions without duplication.

  ## Configuration

      config :dcatr, :manifest_expansion,
        depth: 1,          # 0 = disabled, 1+ = traversal depth
        predicates: nil    # Optional: list of predicates to follow

  ## Example

      ```trig
      # Before MGE - Duplication required
      GRAPH _:service-manifest {
        <#service> prov:wasAttributedTo <#alice> .
        <#alice> foaf:name "Alice" .  # Duplicated!
      }

      GRAPH _:repository-manifest {
        <#repo> dcat:creator <#alice> .
        <#alice> foaf:name "Alice" .  # Duplicated!
      }

      # With MGE - Define once, reference everywhere
      # Default Graph
      <#alice> foaf:name "Alice" .

      GRAPH _:service-manifest {
        <#service> prov:wasAttributedTo <#alice> .  # MGE auto-expands
      }

      GRAPH _:repository-manifest {
        <#repo> dcat:creator <#alice> .  # MGE auto-expands (shared!)
      }
      ```
  """

  alias DCATR.Manifest
  alias DCATR.Manifest.Loader

  @opts [
    depth: 1,
    bnode_depth: :unlimited,
    predicates: nil
  ]

  @doc """
  Expands manifest graph by pulling referenced resources from default graph.

  ## Parameters

  - `manifest_graph` - The manifest graph to expand
  - `default_graph` - Source graph for expansion
  - `opts` - Options (merged with application config and module defaults)

  ## Options

  - `:depth` - Maximum traversal depth for regular resources (default: 1, 0 = disabled)
  - `:bnode_depth` - Maximum traversal depth for blank node resources (default: :unlimited)
  - `:predicates` - Optional list of predicates to follow during expansion (default: all)

  Note: Blank nodes are always expanded with unlimited depth.
  """
  @spec expand(RDF.Graph.t(), RDF.Graph.t(), keyword()) :: RDF.Graph.t()
  def expand(manifest_graph, default_graph, opts \\ []) do
    opts = opts(opts)

    if opts[:depth] == 0 do
      manifest_graph
    else
      seeds = RDF.Graph.objects(manifest_graph)

      Enum.reduce(seeds, manifest_graph, fn resource, acc ->
        RDF.Graph.reachable(
          default_graph,
          resource,
          max_depth: opts[:depth] - 1,
          bnode_depth: opts[:bnode_depth],
          predicates: opts[:predicates],
          into: acc
        )
      end)
    end
  end

  @doc """
  Expands both manifest graphs in a dataset.

  Extracts default graph and both manifest graphs (_:service-manifest and
  _:repository-manifest), expands them via `expand/3`, and writes back
  the expanded graphs.

  ## Parameters

  - `dataset` - The RDF dataset containing manifest graphs
  - `opts` - Options passed to `expand/3`

  ## Returns

  `{:ok, dataset}` with expanded manifest graphs, or unmodified dataset
  if MGE is disabled (depth: 0).
  """
  @spec expand_dataset(RDF.Dataset.t(), keyword()) :: {:ok, RDF.Dataset.t()}
  def expand_dataset(dataset, opts \\ []) do
    default_graph = RDF.Dataset.default_graph(dataset)

    with {:ok, service_manifest} <- Manifest.service_manifest_graph(dataset),
         {:ok, repository_manifest} <- Manifest.repository_manifest_graph(dataset) do
      {:ok,
       dataset
       |> RDF.Dataset.put_graph(expand(service_manifest, default_graph, opts),
         graph: Loader.service_manifest_graph_name()
       )
       |> RDF.Dataset.put_graph(expand(repository_manifest, default_graph, opts),
         graph: Loader.repository_manifest_graph_name()
       )}
    end
  end

  defp opts(opts) do
    @opts
    |> Keyword.merge(Application.get_env(:dcatr, :manifest_expansion, []))
    |> Keyword.merge(opts)
  end
end
