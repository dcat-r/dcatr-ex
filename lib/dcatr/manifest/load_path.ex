defmodule DCATR.Manifest.LoadPath do
  @moduledoc """
  File discovery and classification for `DCATR.Manifest` loading.

  Provides hierarchical file resolution with environment-aware overrides and
  pattern-based classification for graph assignment.
  """

  @type t :: [String.t()]

  @default_load_path "config/dcatr"

  @extensions RDF.Serialization.available_formats() |> Enum.map(& &1.extension())

  @rdf_file_pattern "**/*.{#{Enum.join(@extensions, ",")}}"

  @env_file_pattern Map.new(
                      DCATR.Manifest.environments(),
                      &{&1, "#{&1}/**/*.{#{Enum.join(@extensions, ",")}}"}
                    )
  @env_suffix_pattern Map.new(
                        DCATR.Manifest.environments(),
                        &{&1, "**/*.#{&1}.{#{Enum.join(@extensions, ",")}}"}
                      )

  @ext_pattern Enum.map_join(@extensions, "|", &Regex.escape/1)
  @env_pattern Enum.map_join(DCATR.Manifest.environments(), "|", &to_string/1)

  @doc """
  Returns the configured load path.

  By default, the load path is `#{@default_load_path}`, but can be configured with
  the `:load_path` option of the `:dcatr` application:

      config :dcatr, load_path: ["custom/path"]

  """
  @spec load_path(keyword()) :: t()
  def load_path(opts \\ []) do
    opts
    |> Keyword.get(:load_path, Application.get_env(:dcatr, :load_path, @default_load_path))
    |> List.wrap()
  end

  @doc """
  Resolves the load path into concrete RDF files, with environment-aware ordering.

  Only files with RDF serialization format extensions recognized by `RDF.Serialization`
  are included, in particular: `#{Enum.map_join(@extensions, ", ", &".#{&1}")}`.

  ## File Ordering

  Files are returned in load order to ensure proper precedence during dataset merging
  via `RDF.Dataset.put_properties/2`:

  1. **Per load path directory**: General files before environment-specific files
  2. **Across load paths**: Files from earlier paths before files from later paths

  Within each directory, environment-specific files can use two patterns:

  - Directory-based: `dev/service.ttl`, `prod/service.ttl`
  - Suffix-based: `service.dev.ttl`, `service.prod.ttl`

  Environment-specific files are loaded **after** general files within the same
  directory, but this precedence does **not** apply across different load path
  directories.

  ## Ignored Files

  Files starting with `_` (underscore) are ignored, as are non-existent paths.
  Duplicates across multiple load paths are removed via `Enum.uniq/1`.

  ## Options

  - `:env` - The environment to use (defaults to `Mix.env()`)
  - `:load_path` - Override the configured load path (see `load_path/1`)
  """
  @spec files(keyword()) :: t()
  def files(opts \\ []) do
    env = DCATR.Manifest.env(opts)

    opts
    |> load_path()
    |> Enum.flat_map(fn path ->
      cond do
        not File.exists?(path) -> []
        File.dir?(path) -> find_files_in_directory(path, env)
        true -> [path]
      end
    end)
    |> Enum.uniq()
  end

  defp find_files_in_directory(dir, env) do
    {this_environment_specific_files, other_environment_specific_files} =
      DCATR.Manifest.environments()
      |> Enum.map(fn environment ->
        {environment,
         (dir |> Path.join(@env_suffix_pattern[environment]) |> Path.wildcard()) ++
           (dir |> Path.join(@env_file_pattern[environment]) |> Path.wildcard())}
      end)
      |> Keyword.pop(env)

    dir
    |> Path.join(@rdf_file_pattern)
    |> Path.wildcard()
    |> Kernel.--(other_environment_specific_files |> Keyword.values() |> List.flatten())
    # We're removing and adding the environment-specific files to ensure that they are loaded last
    # having precedence over the general files
    |> Kernel.--(this_environment_specific_files)
    |> Kernel.++(this_environment_specific_files)
    |> Enum.reject(&ignored_file?/1)
    |> Enum.uniq()
  end

  defp ignored_file?(path) do
    Path.basename(path) |> String.starts_with?("_")
  end

  @doc """
  Classifies a manifest file path to determine which manifest graph it belongs to.

  Returns `:service_manifest`, `:repository_manifest`, or `nil` (unclassified).

  ## Classification Rules

  Files are classified based on their path patterns:

  - Service manifest files:
    - `service.(env).(ext)` - Environment-specific service files
    - `/service.(ext)` - Base service file
    - `/service/*.(ext)` - Any file in a `service/` directory

  - Repository manifest files:
    - `repository.(env).(ext)` - Environment-specific repository files
    - `/repository.(ext)` - Base repository file
    - `dataset.(env).(ext)` - Environment-specific dataset files
    - `/dataset.(ext)` - Base dataset file
    - `/repository/*.(ext)` - Any file in a `repository/` directory

  Where `(env)` is one of the `DCATR.Manifest.environments/0` values and `(ext)` is
  any supported RDF serialization format extension.

  Filename patterns take precedence over directory patterns, so `repository/service.ttl`
  is classified as `:service_manifest` (not `:repository_manifest`).

  ## Examples

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/service.ttl")
      :service_manifest

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/service.dev.ttl")
      :service_manifest

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/service/middleware.ttl")
      :service_manifest

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/repository.ttl")
      :repository_manifest

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/dataset.ttl")
      :repository_manifest

      iex> DCATR.Manifest.LoadPath.classify_file("config/dcatr/agent.ttl")
      nil
  """
  @spec classify_file(String.t()) :: :service_manifest | :repository_manifest | nil
  def classify_file(path) do
    cond do
      # Check specific filenames first before directory-based patterns
      path =~ ~r/(^|\/)service\.(#{@env_pattern})\.(#{@ext_pattern})$/ -> :service_manifest
      path =~ ~r/(^|\/)service\.(#{@ext_pattern})$/ -> :service_manifest
      path =~ ~r/(^|\/)repository\.(#{@env_pattern})\.(#{@ext_pattern})$/ -> :repository_manifest
      path =~ ~r/(^|\/)repository\.(#{@ext_pattern})$/ -> :repository_manifest
      path =~ ~r/(^|\/)dataset\.(#{@env_pattern})\.(#{@ext_pattern})$/ -> :repository_manifest
      path =~ ~r/(^|\/)dataset\.(#{@ext_pattern})$/ -> :repository_manifest
      # Directory-based patterns
      path =~ ~r/\/service\/.*\.(#{@ext_pattern})$/ -> :service_manifest
      path =~ ~r/\/repository\/.*\.(#{@ext_pattern})$/ -> :repository_manifest
      true -> nil
    end
  end
end
