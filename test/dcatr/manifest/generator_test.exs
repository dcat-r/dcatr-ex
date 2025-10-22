defmodule DCATR.Manifest.GeneratorTest do
  use DCATR.Case

  doctest DCATR.Manifest.Generator

  alias DCATR.Manifest.{Generator, GeneratorError}

  @moduletag :tmp_dir

  setup context do
    project_dir = context.tmp_dir
    manifest_dir = "config/dcatr"
    on_exit(fn -> File.rm_rf!(project_dir) end)
    {:ok, project_dir: project_dir, manifest_dir: manifest_dir}
  end

  describe "manifest_dir/1" do
    test "with default options" do
      assert Generator.manifest_dir() == {:ok, "config/dcatr"}
    end

    test "with load_path option" do
      assert Generator.manifest_dir(load_path: ["path1", "path2"]) == {:ok, "path2"}
    end

    test "with absolute paths" do
      assert {:error, %GeneratorError{message: message}} =
               Generator.manifest_dir(load_path: ["/path1", "/absolute/path"])

      assert message =~ "Cannot use absolute path as manifest directory: /absolute/path"
      assert message =~ "must be relative to the project directory"
    end
  end

  describe "generate/3" do
    test "initializes service config without adapter", %{
      project_dir: project_dir,
      manifest_dir: manifest_dir
    } do
      assert :ok = Generator.generate(DCATR.Manifest, project_dir)

      assert_files_generated(Path.join(project_dir, manifest_dir))
    end

    test "initializes service config with adapter", %{
      project_dir: project_dir,
      manifest_dir: manifest_dir
    } do
      assert :ok = Generator.generate(DCATR.Manifest, project_dir, adapter: Fuseki)

      manifest_path = Path.join(project_dir, manifest_dir)

      assert_files_generated(manifest_path)

      File.rm_rf!(manifest_path)

      assert :ok = Generator.generate(DCATR.Manifest, project_dir, adapter: Oxigraph)

      assert_files_generated(manifest_path)

      # Load the generated manifest
      assert {:ok, %DCATR.Manifest{} = manifest} =
               DCATR.Manifest.Loader.load(DCATR.Manifest,
                 load_path: [manifest_path],
                 base: EX.__base__()
               )

      # Verify valid service
      assert %DCATR.Service{} = manifest.service
      assert %DCATR.Repository{} = manifest.service.repository
      assert %DCATR.Dataset{} = manifest.service.repository.dataset
    end

    test "with existing directory", %{project_dir: project_dir, manifest_dir: manifest_dir} do
      File.mkdir_p!(Path.join(project_dir, manifest_dir))

      assert {:error, %GeneratorError{message: "Manifest directory already exists: " <> _}} =
               Generator.generate(DCATR.Manifest, project_dir)
    end

    test "with force flag and existing directory", %{
      project_dir: project_dir,
      manifest_dir: manifest_dir
    } do
      manifest_path = Path.join(project_dir, manifest_dir)
      File.mkdir_p!(manifest_path)
      existing_file = Path.join(manifest_path, "repository.ttl")
      File.write!(existing_file, "Original content")

      assert :ok = Generator.generate(DCATR.Manifest, project_dir, force: true)

      refute File.read!(existing_file) == "Original content"
    end

    test "custom template with custom assigns in EEx templates", %{
      project_dir: project_dir,
      manifest_dir: manifest_dir
    } do
      custom_template_dir = Path.join(project_dir, "custom_template")
      File.mkdir_p!(custom_template_dir)
      File.write!(Path.join(custom_template_dir, "custom.ttl.eex"), "<%= @custom_value %>")

      assert :ok =
               Generator.generate(
                 DCATR.Manifest,
                 project_dir,
                 template: custom_template_dir,
                 adapter: Fuseki,
                 assigns: [custom_value: "Test"]
               )

      content = File.read!(Path.join([project_dir, manifest_dir, "custom.ttl"]))
      assert content == "Test"
    end

    test "with non-existent template directory", %{project_dir: project_dir} do
      assert {:error, %GeneratorError{message: "Template does not exist: " <> _}} =
               Generator.generate(DCATR.Manifest, project_dir, template: "non/existent/dir")
    end
  end

  defp assert_files_generated(manifest_dir) do
    assert File.exists?(Path.join(manifest_dir, "service.ttl"))
    assert File.exists?(Path.join(manifest_dir, "repository.ttl"))
  end
end
