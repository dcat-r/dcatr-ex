defmodule DCATR.GraphNotFoundError do
  @moduledoc """
  Raised when a referenced graph cannot be found.
  """
  defexception [:graph_id]

  def message(%{graph_id: nil}), do: "Graph not found"
  def message(%{graph_id: id}), do: "Graph not found: #{id}"
end

defmodule DCATR.DuplicateGraphNameError do
  @moduledoc """
  Raised when multiple graphs have the same local name or when multiple default graphs are designated.
  """
  defexception [:name, :graph_ids]

  def message(%{name: :default, graph_ids: ids}) when is_list(ids) do
    "Multiple default graphs designated: #{Enum.map_join(ids, ", ", &to_string/1)}"
  end

  def message(%{name: name, graph_ids: ids}) when is_list(ids) do
    "Duplicate graph name '#{name}' for graphs: #{Enum.map_join(ids, ", ", &to_string/1)}"
  end

  def message(%{name: :default}), do: "Multiple default graphs designated"
  def message(%{name: name}), do: "Duplicate graph name: #{name}"
end
