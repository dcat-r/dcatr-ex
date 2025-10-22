defmodule DCATR.Manifest.LoadPathTest do
  use DCATR.Case, async: true

  doctest DCATR.Manifest.LoadPath

  alias DCATR.Manifest.LoadPath

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  describe "load_path/1" do
    test "returns default path" do
      assert LoadPath.load_path() == ["config/dcatr"]
    end

    test "returns configured path" do
      assert LoadPath.load_path(load_path: ["custom/path"]) == ["custom/path"]
    end

    test "wraps single path in list" do
      assert LoadPath.load_path(load_path: "custom/path") == ["custom/path"]
    end

    test "uses application config" do
      with_application_env(:dcatr, :load_path, ["app/config/path"], fn ->
        assert LoadPath.load_path() == ["app/config/path"]
      end)
    end
  end

  describe "files/1" do
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "prod"))
      File.mkdir_p!(Path.join(tmp_dir, "dev"))
      File.mkdir_p!(Path.join(tmp_dir, "test"))

      files =
        %{
          manifest_file: Path.join(tmp_dir, "manifest.ttl"),
          prod_file: Path.join(tmp_dir, "prod/specific.ttl"),
          prod_suffix_file: Path.join(tmp_dir, "manifest.prod.rdf"),
          dev_file: Path.join(tmp_dir, "dev/specific.ttl"),
          dev_suffix_file: Path.join(tmp_dir, "manifest.dev.ttl"),
          test_file: Path.join(tmp_dir, "test/specific.ttl"),
          test_suffix_file: Path.join(tmp_dir, "manifest.test.ttl"),
          ignored_file: Path.join(tmp_dir, "_ignored.ttl")
        }

      Enum.each(files, fn {_, path} -> File.touch!(path) end)

      Map.merge(files, %{tmp_dir: tmp_dir})
    end

    test "default opts" do
      assert LoadPath.files() == LoadPath.files(env: :test, load_path: LoadPath.load_path())
    end

    test "handles file paths", ctx do
      assert LoadPath.files(load_path: [ctx.manifest_file]) == [ctx.manifest_file]
    end

    test "finds all relevant files for a given environment", ctx do
      assert LoadPath.files(env: :prod, load_path: [ctx.tmp_dir]) == [
               ctx.manifest_file,
               ctx.prod_suffix_file,
               ctx.prod_file
             ]

      assert LoadPath.files(env: :dev, load_path: [ctx.tmp_dir]) == [
               ctx.manifest_file,
               ctx.dev_suffix_file,
               ctx.dev_file
             ]

      assert LoadPath.files(env: :test, load_path: [ctx.tmp_dir]) == [
               ctx.manifest_file,
               ctx.test_suffix_file,
               ctx.test_file
             ]
    end

    test "supports all RDF serialization formats", %{tmp_dir: tmp_dir} do
      files =
        for ext <- RDF.Serialization.available_formats() |> Enum.map(& &1.extension()) do
          path = Path.join(tmp_dir, "test.#{ext}")
          File.touch!(path)
          path
        end

      found_files = LoadPath.files(load_path: [tmp_dir])

      for file <- files do
        assert file in found_files
      end
    end

    test "handles missing directories" do
      assert LoadPath.files(load_path: ["non/existent/path"]) == []
    end

    test "empty directory returns empty list", %{tmp_dir: tmp_dir} do
      empty_dir = Path.join(tmp_dir, "empty")
      File.mkdir_p!(empty_dir)

      assert LoadPath.files(load_path: [empty_dir]) == []
    end

    test "directory with nested environment subdirectories", %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "dev/nested"))
      nested_file = Path.join(tmp_dir, "dev/nested/config.ttl")
      File.touch!(nested_file)

      assert nested_file in LoadPath.files(env: :dev, load_path: [tmp_dir])
    end
  end

  describe "files/1 with multiple load paths" do
    setup %{tmp_dir: tmp_dir} do
      path1 = Path.join(tmp_dir, "path1")
      path2 = Path.join(tmp_dir, "path2")

      File.mkdir_p!(path1)
      File.mkdir_p!(path2)

      files = %{
        path1_general: Path.join(path1, "manifest.ttl"),
        path2_general: Path.join(path2, "manifest.ttl"),
        path1_dev: Path.join(path1, "manifest.dev.ttl"),
        path2_dev: Path.join(path2, "manifest.dev.ttl")
      }

      Enum.each(files, fn {_, path} -> File.touch!(path) end)

      Map.merge(files, %{path1: path1, path2: path2})
    end

    test "environment-specific ordering preserved across multiple paths", ctx do
      assert LoadPath.files(env: :dev, load_path: [ctx.path1, ctx.path2]) == [
               ctx.path1_general,
               ctx.path1_dev,
               ctx.path2_general,
               ctx.path2_dev
             ]
    end

    test "duplicate files are removed", %{tmp_dir: tmp_dir} do
      shared_path = Path.join(tmp_dir, "shared")
      shared_file = Path.join(shared_path, "manifest.ttl")
      File.mkdir_p!(shared_path)
      File.touch!(shared_file)

      assert LoadPath.files(load_path: [shared_path, shared_path]) == [shared_file]
    end

    test "mixed file and directory paths", %{tmp_dir: tmp_dir} do
      dir = Path.join(tmp_dir, "manifests")
      File.mkdir_p!(dir)
      dir_file = Path.join(dir, "service.ttl")
      direct_file = Path.join(tmp_dir, "direct.ttl")
      File.touch!(dir_file)
      File.touch!(direct_file)

      files = LoadPath.files(load_path: [dir, direct_file])

      assert dir_file in files
      assert direct_file in files
    end
  end

  test "classify_file/1" do
    for {type, files} <- %{
          service_manifest: [
            "/path/to/service",
            "/path/to/service/anything",
            "/path/to/service/config",
            "/deep/nested/path/service",
            "/deep/nested/path/service/config",
            # relative paths
            "service",
            # root-level
            "/service"
          ],
          repository_manifest: [
            "/path/to/repository",
            "/path/to/dataset",
            "/path/to/repository/anything",
            "/path/to/repository/dataset",
            "/deep/nested/path/repository",
            "/deep/nested/path/repository/data",
            # relative paths
            "repository",
            "dataset",
            # root-level
            "/repository",
            "/dataset"
          ],
          nil: [
            "/path/to/agent",
            "/path/to/other",
            "/path/to/data",
            # service/repository in name but not exact match
            "/path/to/my_service",
            "/path/to/service_config",
            "/path/to/repository_data"
          ]
        },
        file <- files,
        env <- ["" | DCATR.Manifest.environments() |> Enum.map(&".#{&1}")],
        ext <- RDF.Serialization.available_formats() |> Enum.map(& &1.extension()) do
      path = "#{file}#{env}.#{ext}"

      assert LoadPath.classify_file(path) == type,
             "Expected #{inspect(path)} to be classified as #{inspect(type)}, but got #{inspect(LoadPath.classify_file(path))}"
    end

    # Edge cases: unknown extensions
    assert LoadPath.classify_file("/path/to/service.json") == nil
    assert LoadPath.classify_file("/path/to/service.txt") == nil
    assert LoadPath.classify_file("/path/to/repository.xml") == nil
    assert LoadPath.classify_file("/path/to/dataset.csv") == nil

    # Edge cases: unknown environments
    assert LoadPath.classify_file("/path/to/service.staging.ttl") == nil
    assert LoadPath.classify_file("/path/to/service.local.ttl") == nil
    assert LoadPath.classify_file("/path/to/repository.staging.ttl") == nil
    assert LoadPath.classify_file("/path/to/dataset.custom.ttl") == nil

    # Edge cases: filename patterns take precedence over directory patterns
    assert LoadPath.classify_file("/path/to/repository/service.ttl") == :service_manifest
    assert LoadPath.classify_file("/path/to/service/repository.ttl") == :repository_manifest
    assert LoadPath.classify_file("/path/to/service/dataset.ttl") == :repository_manifest
  end
end
