defmodule DCATR.Manifest.Generator do
  @moduledoc """
  Generates `DCATR.Manifest` files for DCAT-R repositories from EEx templates.

  Manifest files define service and repository configuration in RDF files. The generator
  creates these files from customizable templates, enabling project scaffolding and custom
  manifest type initialization.

  The generator integrates with `DCATR.Manifest.LoadPath` to determine the target directory
  and supports EEx templating for dynamic content generation.
  """

  alias DCATR.Manifest.{LoadPath, GeneratorError}

  @doc """
  Returns the default template directory for manifest generation.

  ## Configuration

  The default template directory can be configured with the `:manifest_template_dir` option
  of the `:dcatr` application configuration:

      config :dcatr, manifest_template_dir: "custom/path"

  """
  def default_template_dir do
    Application.get_env(
      :dcatr,
      :manifest_template_dir,
      :dcatr |> :code.priv_dir() |> Path.join("manifest_template")
    )
  end

  @doc """
  Returns the manifest directory path within the project directory.

  The manifest directory is determined from the configured load path.
  The last path in the load path with the highest precedence is used,
  since it is the most specific path.

  Returns an error if the last path in the load path is absolute, since
  manifest directories must be relative to the project directory.
  """
  @spec manifest_dir(keyword()) :: {:ok, Path.t()} | {:error, any()}
  def manifest_dir(opts \\ []) do
    manifest_dir = LoadPath.load_path(opts) |> List.last()

    if Path.type(manifest_dir) == :absolute do
      {:error,
       GeneratorError.exception("""
       Cannot use absolute path as manifest directory: #{manifest_dir}

       The manifest directory must be relative to the project directory to ensure proper
       organization of project files. Please use a relative path instead.
       """)}
    else
      {:ok, manifest_dir}
    end
  end

  @doc """
  Generates the manifest files for a DCATR repository.

  The `project_dir` is the root directory of the project where additional directories
  may be created by custom manifest types. The manifest files themselves will be
  generated in a subdirectory determined by the last path in the load path.

  ## Options

  - `:template` - Custom template directory (default: uses `manifest_type.generator_template/0`)
  - `:force` - Overwrite existing manifest directory (default: `false`)
  - `:assigns` - Keyword list of assigns for EEx templates (e.g., `[service_title: "My Service"]`)

  ## Examples

      # Generate default manifests in config/dcatr/
      Generator.generate(DCATR.Manifest, "/path/to/project")

      # Use custom template with EEx assigns
      Generator.generate(
        DCATR.Manifest,
        "/path/to/project",
        template: "/custom/templates",
        assigns: [service_title: "My Service", creator: "http://example.org/me"]
      )
  """
  @spec generate(DCATR.Manifest.Type.t(), Path.t(), keyword()) :: :ok | {:error, any()}
  def generate(manifest_type, project_dir, opts \\ []) do
    with {:ok, manifest_dir} <- manifest_dir(opts),
         destination = Path.join(project_dir, manifest_dir),
         :ok <- create_manifest_dir(destination, Keyword.get(opts, :force, false)),
         {:ok, template_dir} <-
           Keyword.get(opts, :template, manifest_type.generator_template())
           |> check_template() do
      template_dir
      |> File.ls!()
      |> Enum.each(fn file ->
        base_file = Path.basename(file, ".eex")
        eex? = file != base_file

        copy_file!(
          Path.join(template_dir, file),
          Path.join(destination, base_file),
          eex? &&
            opts
            |> Keyword.get(:assigns, [])
        )
      end)

      :ok
    end
  end

  defp create_manifest_dir(dir, force?) do
    cond do
      not File.exists?(dir) -> File.mkdir_p(dir)
      force? -> :ok
      true -> {:error, GeneratorError.exception("Manifest directory already exists: #{dir}")}
    end
  end

  defp check_template(template) do
    if File.exists?(template) do
      {:ok, template}
    else
      {:error, GeneratorError.exception("Template does not exist: #{template}")}
    end
  end

  defp copy_file!(source, dest, false), do: File.copy!(source, dest)

  defp copy_file!(source, dest, assigns) do
    File.write!(dest, EEx.eval_file(source, assigns: assigns))
  end
end
