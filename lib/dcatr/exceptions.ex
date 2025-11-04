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
  defexception [:name, :graphs, :reason, :context]

  @impl true
  def message(%{
        name: :default,
        graphs: [primary, explicit],
        reason: :use_primary_as_default_enforced
      }) do
    """
    Default graph conflict: usePrimaryAsDefault is enforced (true), but default graph differs from primary graph.

    Expected: #{inspect(primary)} (primary graph)
    Actual:   #{inspect(explicit)} (designated as default)

    Solutions:
    - Remove usePrimaryAsDefault to fall back to auto mode
    - Set usePrimaryAsDefault: false (disable enforcement)
    - Remove explicit default designation to use primary graph
    """
  end

  def message(%{name: :default, graphs: ids, reason: :explicit_duplicates}) when is_list(ids) do
    """
    Multiple graphs designated as default: #{inspect(ids)}

    Solutions:
    - Remove dcatr:DefaultGraph type from all but one graph
    - Use usePrimaryAsDefault to automatically designate primary graph as default
    """
  end

  def message(%{name: name, graphs: ids}) when is_list(ids) do
    """
    Duplicate graph name: #{inspect(name)} is assigned to multiple graphs: #{inspect(ids)}

    Solutions:
    - Ensure each dcatr:localGraphName is unique within the service
    """
  end

  def message(%{name: :default}), do: "Multiple default graphs designated"
  def message(%{name: name}), do: "Duplicate graph name: #{name}"
end

defmodule DCATR.Manifest.GeneratorError do
  @moduledoc """
  Raised on errors when generating `DCATR.Manifest` files.
  """
  defexception [:message]
end

defmodule DCATR.Manifest.LoadingError do
  @moduledoc """
  Raised on errors when loading a `DCATR.Manifest` graph.
  """
  defexception [:file, :reason]

  @type t :: %__MODULE__{file: String.t() | nil, reason: any()}

  def message(%{file: nil, reason: :missing}) do
    "No manifest files found"
  end

  def message(%{file: nil, reason: reason}) do
    "Invalid manifest: #{inspect(reason)}"
  end

  def message(%{file: file, reason: reason}) do
    "Invalid manifest file #{file}: #{inspect(reason)}"
  end
end

defmodule DCATR.ManifestError do
  @moduledoc """
  Raised on errors with `DCATR.Manifest`.
  """
  defexception [:data, :reason]

  @type t :: %__MODULE__{data: any(), reason: atom()}

  def message(%{data: data, reason: :no_service}) do
    "Manifest does not contain a unique service: #{inspect(data)}"
  end

  def message(%{data: conflicting_services, reason: :multiple_services}) do
    "Manifest contains multiple services: #{inspect(Enum.map_join(conflicting_services, ", ", & &1.service))}"
  end

  def message(%{data: service_data_ids, reason: :multiple_service_data}) do
    "Service has multiple dcatr:serviceLocalData values: #{Enum.map_join(service_data_ids, ", ", &to_string/1)}"
  end

  def message(%{data: manifest_graph_ids, reason: :multiple_service_manifest_graphs}) do
    "ServiceData has multiple dcatr:serviceManifestGraph values: #{Enum.map_join(manifest_graph_ids, ", ", &to_string/1)}"
  end

  def message(%{data: _data, reason: :no_service_graph}) do
    "Manifest does not contain a service manifest graph (_:service-manifest)"
  end

  def message(%{data: _data, reason: :no_repository_graph}) do
    "Manifest does not contain a repository manifest graph (_:repository-manifest)"
  end

  def message(%{data: data, reason: reason}) do
    "Invalid manifest #{inspect(data)}: #{inspect(reason)}"
  end
end
