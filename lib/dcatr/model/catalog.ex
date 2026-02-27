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

  ## Return values

  - `%DCATR.Graph{}` - Selector resolved successfully to a graph
  - `nil` - Selector is recognized but references no graph (e.g., `:primary` when no primary graph is defined)
  - `:undefined` - Selector is not recognized by this implementation (enables delegation in hierarchies)

  Implementations should only handle their own selectors and return `:undefined` for unknown ones.
  """
  @callback resolve_graph_selector(catalog :: schema(), selector()) ::
              DCATR.Graph.t() | nil | :undefined

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.Catalog

      @doc """
      Returns a graph by ID or symbolic selector.

      Tries `resolve_graph_selector/2` first. On `:undefined`, falls back to
      `find_graph/2` (from `DCATR.Directory.Type`) for ID-based lookup.
      """
      @spec graph(DCATR.Catalog.schema(), DCATR.Catalog.id_or_selector()) ::
              DCATR.Graph.t() | nil
      def graph(catalog, id_or_selector) do
        case resolve_graph_selector(catalog, id_or_selector) do
          :undefined -> find_graph(catalog, RDF.coerce_graph_name(id_or_selector))
          result -> result
        end
      end

      @doc """
      Checks if a graph exists in the catalog.

      Convenience function based on `graph/2` - returns `true` if the graph exists,
      `false` otherwise.
      """
      @spec has_graph?(DCATR.Catalog.schema(), DCATR.Catalog.id_or_selector()) :: boolean()
      def has_graph?(catalog, id_or_selector) do
        graph(catalog, id_or_selector) != nil
      end

      defoverridable graph: 2, has_graph?: 2
    end
  end
end
