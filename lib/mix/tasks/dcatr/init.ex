defmodule Mix.Tasks.Dcatr.Init do
  @moduledoc """
  Initializes a DCAT-R manifest for the current project.

  ## Usage

      mix dcatr.init

  ## Options

  - `--type` - Custom manifest type module (default: from config or `DCATR.Manifest`)
  - `--template` - Path to custom template directory
  - `--force` - Overwrite existing manifest directory
  - Additional options are passed as assigns to EEx templates

  ## Examples

      # Initialize with default manifest type
      mix dcatr.init

      # Use custom manifest type
      mix dcatr.init --type MyApp.CustomManifest

      # Pass assigns to templates
      mix dcatr.init --type Gno.Manifest --adapter Fuseki

      # Force overwrite
      mix dcatr.init --force
  """

  @shortdoc "Initializes a DCAT-R manifest"

  use Mix.Task

  alias DCATR.Manifest.GeneratorError

  @switches [
    type: :string,
    template: :string,
    force: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches, allow_nonexistent_atoms: true)
    {type, opts} = Keyword.pop(opts, :type)
    {generator_opts, assigns} = Keyword.split(opts, [:template, :force])
    generator_opts = Keyword.put(generator_opts, :assigns, assigns)
    project_dir = File.cwd!()
    manifest_type = manifest_type(type)

    case manifest_type.generate(project_dir, generator_opts) do
      :ok -> Mix.shell().info("Initialized #{inspect(manifest_type)} manifest successfully")
      {:error, %GeneratorError{message: message}} -> Mix.raise(message)
      {:error, error} -> Mix.raise("Failed to initialize manifest: #{inspect(error)}")
    end
  end

  defp manifest_type(nil), do: Application.get_env(:dcatr, :manifest_type, DCATR.Manifest)
  defp manifest_type(type), do: Module.concat([type])
end
