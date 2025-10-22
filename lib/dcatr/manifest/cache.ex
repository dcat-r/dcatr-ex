defmodule DCATR.Manifest.Cache do
  @moduledoc """
  In-memory caching for loaded `DCATR.Manifest`s using ETS.

  The cache stores loaded manifests to avoid re-parsing and reloading from files
  on repeated access.

  ## Architecture

  - **GenServer-based**: Automatically started by the DCAT-R application supervisor
  - **ETS storage**: Public ETS table with read concurrency enabled for fast parallel reads
  - **Cache key**: Tuples of `{manifest_type, load_path}` ensuring distinct caches per configuration
  - **Manual invalidation**: No automatic file watching - use `invalidate/2` or `clear/0` to refresh

  ## Usage

  The cache is transparent when using `DCATR.Manifest.Cache.manifest/2`:

      # First call: loads from files and caches
      {:ok, manifest} = Cache.manifest(DCATR.Manifest)

      # Subsequent calls: returns cached manifest instantly
      {:ok, ^manifest} = Cache.manifest(DCATR.Manifest)

      # Force reload: bypass cache and refresh
      {:ok, new_manifest} = Cache.manifest(DCATR.Manifest, reload: true)

  ## Cache Invalidation

  Manual invalidation strategies:

  - **Selective invalidation**: `invalidate(manifest_type, opts)` - Invalidates specific manifest
  - **Full clear**: `clear/0` - Removes all cached manifests
  - **Reload option**: Pass `reload: true` to `manifest/2` - Bypasses cache and updates it
  - **Application restart**: ETS table is recreated, implicitly clearing cache

  Note: There is no automatic file watching or invalidation on file changes.
  """

  use GenServer

  alias DCATR.{Manifest, ManifestError}
  alias DCATR.Manifest.{LoadPath, Loader}

  @table_name :dcatr_manifest_cache

  @type cache_key :: {Manifest.Type.t(), String.t()}

  @typedoc "GenServer state containing the ETS table reference"
  @type state :: %{table: :ets.table()}

  @doc """
  Starts the cache GenServer.

  This function is called automatically by the DCAT-R application supervisor.
  The `opts` are passed to `GenServer.start_link/3` but are not used for
  cache initialization.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @doc """
  Gets a manifest from the cache or loads it if not present or if reload is requested.

  The cache key is `{manifest_type, load_path}`, so manifests with different
  load paths are cached separately.

  ## Options

  - `:reload` - When `true`, forces reloading the manifest and updates the cache
  - `:load_path` - Custom load path (affects cache key)
  - Any other options are passed to `DCATR.Manifest.Loader.load/2`
  """
  @spec manifest(Manifest.Type.t(), keyword()) ::
          {:ok, Manifest.Type.schema()} | {:error, ManifestError.t()}
  def manifest(manifest_type, opts \\ []) do
    {reload?, opts} = Keyword.pop(opts, :reload, false)
    key = {manifest_type, LoadPath.load_path(opts)}

    if reload? do
      load_and_cache(manifest_type, key, opts)
    else
      case :ets.lookup(@table_name, key) do
        [{^key, manifest}] -> {:ok, manifest}
        [] -> load_and_cache(manifest_type, key, opts)
      end
    end
  end

  defp load_and_cache(manifest_type, key, opts) do
    with {:ok, manifest} = result <- Loader.load(manifest_type, opts) do
      :ets.insert(@table_name, {key, manifest})
      result
    end
  end

  @doc """
  Removes a specific manifest from the cache.

  If the manifest is not cached, this is a no-op.

  ## Options

  - `:load_path` - Custom load path (affects cache key)
  """
  @spec invalidate(Manifest.Type.t(), keyword()) :: :ok
  def invalidate(manifest_type, opts \\ []) do
    :ets.delete(@table_name, {manifest_type, LoadPath.load_path(opts)})

    :ok
  end

  @doc """
  Clears the entire cache.

  Useful for testing purposes.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end
end
