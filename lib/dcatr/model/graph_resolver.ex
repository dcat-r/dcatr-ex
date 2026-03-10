defmodule DCATR.GraphResolver do
  @moduledoc """
  Behaviour for graph lookup via symbolic selectors.

  This module provides graph access by ID or symbolic selector (e.g., `:primary`,
  `:repository_manifest`). Each container type defines its own selectors for
  commonly needed graphs.

  Structural operations (member enumeration, directory traversal) are in
  `DCATR.Directory.Type`, while this behaviour adds named graph access on top.

  ## Core Callback

  - `c:resolve_graph_selector/2` - Resolve symbolic selectors to graphs

  ## Generated Functions

  The `__using__` macro generates:

  - `graph/2` — calls `resolve_graph_selector/2`, falls back to `find_graph/2` (from `DCATR.Directory.Type`)
  - `has_graph?/2` — `graph/2 != nil`

  Both are `defoverridable`.
  """

  @type t :: module()
  @type container :: Grax.Schema.t()
  @type selector :: atom()
  @type id_or_selector :: selector() | RDF.IRI.coercible()

  @doc """
  Resolves a symbolic selector to a graph.

  Each container type defines selectors for its commonly needed graphs
  (e.g., `:primary` on repositories, `:service_manifest` on service data).

  ## Return values

  - `%DCATR.Graph{}` - Selector resolved successfully to a graph
  - `nil` - Selector is recognized but references no graph (e.g., `:primary` when no primary graph is defined)
  - `:undefined` - Selector is not recognized by this implementation (enables delegation in hierarchies)

  Implementations should only handle their own selectors and return `:undefined` for unknown ones.
  """
  @callback resolve_graph_selector(container(), selector()) :: DCATR.Graph.t() | nil | :undefined

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.GraphResolver

      @doc """
      Returns a graph by ID or symbolic selector.

      Tries `resolve_graph_selector/2` first. On `:undefined`, falls back to
      `find_graph/2` (from `DCATR.Directory.Type`) for ID-based lookup.
      """
      @spec graph(DCATR.GraphResolver.container(), DCATR.GraphResolver.id_or_selector()) ::
              DCATR.Graph.t() | nil
      def graph(container, id_or_selector) do
        case resolve_graph_selector(container, id_or_selector) do
          :undefined -> find_graph(container, RDF.coerce_graph_name(id_or_selector))
          result -> result
        end
      end

      @doc """
      Checks if a graph exists in the container.

      Convenience function based on `graph/2` - returns `true` if the graph exists,
      `false` otherwise.
      """
      @spec has_graph?(DCATR.GraphResolver.container(), DCATR.GraphResolver.id_or_selector()) ::
              boolean()
      def has_graph?(container, id_or_selector) do
        graph(container, id_or_selector) != nil
      end

      defoverridable graph: 2, has_graph?: 2
    end
  end
end
