defmodule DCATR.Catalog do
  @moduledoc """
    Behaviour for DCAT catalog structures managing collections of graphs.

    This module defines the foundational catalog API implemented by `DCATR.Dataset`, `DCATR.Repository`,
    `DCATR.ServiceData` and, `DCATR.Service`. Catalogs provide unified access to graph collections via
    IDs and symbolic selectors, enabling hierarchical composition and domain-specific extensions.

    The behaviour automatically provides a `has_graph?/2` convenience function for
    existence checks based on `c:graph/2`.

    ## Core Callbacks

    - `c:resolve_graph_selector/2` - Resolve symbolic shortcuts to graphs
    - `c:graph/2` - Primary graph access API (by ID or selector)
    - `c:graphs/2` - Retrieve all graphs with optional type filtering
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()
  @type selector :: atom()
  @type id_or_selector :: selector() | RDF.IRI.coercible()

  @doc """
  Resolves a symbolic selector to a graph.

  This callback enables catalog implementations to provide domain-specific shortcuts for
  accessing frequently used graphs (e.g., `:repository_manifest`, `:service_manifest`).
  It separates selector resolution logic from ID-based lookup, enabling composition and
  reuse across catalog hierarchies.

  It is usually used by `c:graph/2` implementation during the first resolution stage (before ID lookup).

  Implementations should only handle their own selectors and return `nil` for unknown ones.
  """
  @callback resolve_graph_selector(catalog :: schema(), selector()) :: DCATR.Graph.t() | nil

  @doc """
  Returns a graph by ID or symbolic selector.

  This callback is the primary graph access API for all catalog types, enabling
  unified graph retrieval while allowing custom resolution logic.

  Implementations should delegate to `c:resolve_graph_selector/2` for symbolic selectors,
  then search by graph ID, returning `nil` if no match is found.
  """
  @callback graph(catalog :: schema(), id_or_selector()) :: DCATR.Graph.t() | nil

  @doc """
  Returns all graphs in the catalog.

  This callback provides bulk access to the catalog's graph collection, enabling
  iteration and type-based filtering.

  Implementations should return a flat list of all graphs by default, and support
  `:type` filtering for graph type subsets (e.g., `:data`, `:system`, `:manifest`).

  ## Options

  - `:type` - Filter by graph type (atom or list of atoms, catalog-specific)
  """
  @callback graphs(catalog :: schema(), opts :: keyword()) :: [DCATR.Graph.t()]

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.Catalog

      @doc """
      Checks if a graph exists in the catalog.

      Convenience function based on `c:DCATR.Catalog.graph/2` - returns `true` if the graph exists,
      `false` otherwise.
      """
      @spec has_graph?(DCATR.Catalog.schema(), DCATR.Catalog.id_or_selector()) :: boolean()
      def has_graph?(catalog, id_or_selector) do
        graph(catalog, id_or_selector) != nil
      end
    end
  end
end
