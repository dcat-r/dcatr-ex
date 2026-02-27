defmodule DCATR.Directory.Type do
  @moduledoc """
  Behaviour for directory-like containers with structural graph organization.

  This module defines the structural layer for containers that hold `DCATR.Element`s
  (graphs and nested directories). It provides two callbacks for direct member access
  and generates derived and recursive functions for traversal.

  ## Callbacks

  - `c:graphs/1` - direct graph members
  - `c:directories/1` - direct directory members

  ## Generated Functions

  - `members/1` - all direct elements (`graphs/1 ++ directories/1`)
  - `all_graphs/1` - all graphs recursively through sub-directories
  - `all_members/1` - all elements recursively through sub-directories
  - `find_graph/2` - find a graph by ID recursively

  ## Usage

  Modules that `use DCATR.Directory.Type` get:

  - `@behaviour DCATR.Directory.Type` declared
  - `use Grax.Schema` included
  - Default implementations of 2 callbacks (operating on `members` field)
  - Implementations of 4 generated functions (using polymorphic dispatch)
  - All 6 functions are `defoverridable`

  Override the callbacks when your module uses typed fields instead of `members`:

      @impl DCATR.Directory.Type
      def graphs(%_dataset{special_graph: special, other_graphs: graphs}), do: [special | graphs]

      @impl DCATR.Directory.Type
      def directories(%_dataset{directories: directories}), do: directories || []
  """

  @type t :: module()
  @type schema :: Grax.Schema.t()

  @doc """
  Returns direct graph members only.
  """
  @callback graphs(container :: schema()) :: [DCATR.Graph.t()]

  @doc """
  Returns direct directory members only.
  """
  @callback directories(container :: schema()) :: [DCATR.Directory.t()]

  defmacro __using__(_) do
    quote do
      @behaviour DCATR.Directory.Type
      use Grax.Schema

      @impl DCATR.Directory.Type
      def graphs(container), do: DCATR.Directory.Type.graphs(container)

      @impl DCATR.Directory.Type
      def directories(container), do: DCATR.Directory.Type.directories(container)

      @doc """
      Returns all direct element members.
      """
      @spec members(DCATR.Directory.Type.schema()) :: [DCATR.Element.t()]
      def members(container), do: DCATR.Directory.Type.members(container)

      @doc """
      Returns all graphs through the entire sub-directory tree.
      """
      @spec all_graphs(DCATR.Directory.Type.schema()) :: [DCATR.Graph.t()]
      def all_graphs(container), do: DCATR.Directory.Type.all_graphs(container)

      @doc """
      Returns all elements through the entire sub-directory tree.
      """
      @spec all_members(DCATR.Directory.Type.schema()) :: [DCATR.Element.t()]
      def all_members(container), do: DCATR.Directory.Type.all_members(container)

      @doc """
      Finds a graph by ID recursively through the sub-directory tree.
      """
      @spec find_graph(DCATR.Directory.Type.schema(), RDF.IRI.coercible()) ::
              DCATR.Graph.t() | nil
      def find_graph(container, id), do: DCATR.Directory.Type.find_graph(container, id)

      defoverridable members: 1,
                     graphs: 1,
                     directories: 1,
                     all_graphs: 1,
                     all_members: 1,
                     find_graph: 2
    end
  end

  # Default callback implementations (operating on `members` field)

  @doc """
  Default implementation of `c:graphs/1`.

  Filters `members` for Graph instances.
  """
  @spec graphs(schema()) :: [DCATR.Graph.t()]
  def graphs(%_directory_type{members: members}) do
    Enum.filter(members, &graph?/1)
  end

  @doc """
  Default implementation of `c:directories/1`.

  Filters `members` for Directory instances.
  """
  @spec directories(schema()) :: [DCATR.Directory.t()]
  def directories(%_directory_type{members: members}) do
    Enum.filter(members, &directory?/1)
  end

  # Generated function implementations (using polymorphic dispatch)

  @doc """
  Returns all direct element members.

  Combines `graphs/1` and `directories/1` via polymorphic dispatch.
  """
  @spec members(schema()) :: [DCATR.Element.t()]
  def members(%module{} = container) do
    module.graphs(container) ++ module.directories(container)
  end

  # Recursive implementations (using polymorphic dispatch)

  @doc """
  Returns all Graphs through the entire sub-directory tree.

  Uses polymorphic dispatch to call the correct `graphs/1` and `directories/1`
  on each nested container.
  """
  @spec all_graphs(schema()) :: [DCATR.Graph.t()]
  def all_graphs(%module{} = container) do
    module.graphs(container) ++
      Enum.flat_map(module.directories(container), &dispatch(&1, :all_graphs))
  end

  @doc """
  Returns all Elements through the entire sub-directory tree.

  Uses polymorphic dispatch to call the correct `members/1` on each nested container.
  """
  @spec all_members(schema()) :: [DCATR.Element.t()]
  def all_members(%module{} = container) do
    Enum.flat_map(module.members(container), fn member ->
      if directory?(member) do
        [member | dispatch(member, :all_members)]
      else
        [member]
      end
    end)
  end

  @doc """
  Finds a Graph by ID recursively through the sub-directory tree.

  Uses polymorphic dispatch to search through nested containers.
  """
  @spec find_graph(schema(), RDF.IRI.coercible()) :: DCATR.Graph.t() | nil
  def find_graph(%module{} = container, id) do
    graph_id = RDF.coerce_graph_name(id)

    Enum.find(module.graphs(container), &(&1.__id__ == graph_id)) ||
      Enum.find_value(module.directories(container), &dispatch(&1, :find_graph, [graph_id]))
  end

  # Polymorphic dispatch helpers

  defp dispatch(%module{} = entity, fun), do: apply(module, fun, [entity])
  defp dispatch(%module{} = entity, fun, args), do: apply(module, fun, [entity | args])

  defp graph?(struct), do: Grax.Schema.inherited_from?(struct, DCATR.Graph)
  defp directory?(struct), do: Grax.Schema.inherited_from?(struct, DCATR.Directory)
end
