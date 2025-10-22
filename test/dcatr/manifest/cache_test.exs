defmodule DCATR.Manifest.CacheTest do
  use DCATR.Case

  doctest DCATR.Manifest.Cache

  alias DCATR.Manifest
  alias DCATR.Manifest.{Cache, LoadingError}

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  describe "manifest/2" do
    test "caches default manifest from config/dcatr path" do
      assert {:ok, default_manifest} = Cache.manifest(Manifest)
      assert {:ok, ^default_manifest} = Cache.manifest(Manifest)
    end

    test "loads and caches a manifest", %{tmp_dir: tmp_dir} do
      %{manifest_file: manifest_file, load_path: load_path} = setup_manifest(tmp_dir)

      assert {:ok, manifest} = Cache.manifest(Manifest, load_path: load_path)
      assert manifest != Cache.manifest(Manifest)

      modify(manifest_file)

      assert {:ok, ^manifest} = Cache.manifest(Manifest, load_path: load_path)
      assert {:ok, new_manifest} = Cache.manifest(Manifest, load_path: load_path, reload: true)
      assert manifest != new_manifest
    end

    test "handles errors from loader" do
      assert {:error, %LoadingError{reason: :missing}} =
               Cache.manifest(Manifest, load_path: "non_existent_path")
    end

    test "handles deleted manifest files gracefully", %{tmp_dir: tmp_dir} do
      %{manifest_file: manifest_file, load_path: load_path} = setup_manifest(tmp_dir)

      assert {:ok, manifest} = Cache.manifest(Manifest, load_path: load_path)

      File.rm!(manifest_file)

      assert {:ok, ^manifest} = Cache.manifest(Manifest, load_path: load_path)

      assert {:error, %LoadingError{reason: :missing}} =
               Cache.manifest(Manifest, load_path: load_path, reload: true)
    end
  end

  describe "clear/0" do
    test "removes all entries from the cache", %{tmp_dir: tmp_dir} do
      %{manifest_file: manifest_file, load_path: load_path} = setup_manifest(tmp_dir)

      assert {:ok, manifest} = Cache.manifest(Manifest, load_path: load_path)

      modify(manifest_file)

      assert :ok = Cache.clear()

      assert {:ok, new_manifest} = Cache.manifest(Manifest, load_path: load_path)
      assert manifest != new_manifest
    end

    test "clearing empty cache is safe" do
      assert :ok = Cache.clear()
      assert :ok = Cache.clear()
    end
  end

  describe "invalidate/2" do
    test "invalidates specific manifest type with specific load path", %{tmp_dir: tmp_dir} do
      %{manifest_file: manifest_file1, load_path: load_path1} = setup_manifest(tmp_dir, "dir1")
      %{manifest_file: manifest_file2, load_path: load_path2} = setup_manifest(tmp_dir, "dir2")

      assert {:ok, manifest1} = Cache.manifest(Manifest, load_path: load_path1)
      assert {:ok, manifest2} = Cache.manifest(Manifest, load_path: load_path2)

      modify(manifest_file1)
      modify(manifest_file2)

      assert :ok = Cache.invalidate(Manifest, load_path: load_path1)

      assert {:ok, new_manifest1} = Cache.manifest(Manifest, load_path: load_path1)
      assert {:ok, ^manifest2} = Cache.manifest(Manifest, load_path: load_path2)

      assert manifest1 != new_manifest1
    end

    test "invalidating non-existent manifest is a no-op" do
      assert :ok = Cache.invalidate(Manifest, load_path: "/non/existent/path")
    end
  end

  describe "concurrent access" do
    test "multiple processes can read cached manifests concurrently", %{tmp_dir: tmp_dir} do
      %{load_path: load_path} = setup_manifest(tmp_dir)

      # Load manifest into cache
      assert {:ok, manifest} = Cache.manifest(Manifest, load_path: load_path)

      # Spawn multiple processes reading the same manifest concurrently
      tasks =
        1..10
        |> Enum.map(fn _i ->
          Task.async(fn ->
            Cache.manifest(Manifest, load_path: load_path)
          end)
        end)

      # All should return the same cached manifest
      results = Task.await_many(tasks)

      assert Enum.all?(results, &match?({:ok, ^manifest}, &1))
    end
  end

  describe "multiple manifest types" do
    test "different manifest types are cached independently", %{tmp_dir: tmp_dir} do
      %{load_path: load_path} = setup_manifest(tmp_dir)

      # Load two different manifest types with same load path
      assert {:ok, manifest1} =
               Cache.manifest(Manifest, load_path: load_path, manifest_id: EX.manifest1())

      assert {:ok, manifest2} =
               Cache.manifest(CustomManifest, load_path: load_path, manifest_id: EX.manifest2())

      # They should be different (different types)
      assert manifest1.__struct__ == Manifest
      assert manifest2.__struct__ == CustomManifest

      # Invalidating one should not affect the other
      assert :ok = Cache.invalidate(Manifest, load_path: load_path)

      assert {:ok, new_manifest1} =
               Cache.manifest(Manifest, load_path: load_path, manifest_id: EX.manifest1())

      assert {:ok, ^manifest2} =
               Cache.manifest(CustomManifest, load_path: load_path, manifest_id: EX.manifest2())

      # New manifest should be reloaded
      assert new_manifest1 == manifest1
    end
  end

  defp setup_manifest(tmp_dir, subdir \\ nil) do
    dir = if subdir, do: Path.join(tmp_dir, subdir), else: tmp_dir
    File.mkdir_p!(dir)

    manifest_file = Path.join(dir, "manifest.trig")
    File.cp!(TestData.manifest("single_file.trig"), manifest_file)

    %{manifest_file: manifest_file, load_path: dir}
  end

  defp modify(manifest_file) do
    File.write!(
      manifest_file,
      "<http://example.com/Repository> <http://purl.org/dc/elements/1.1/title> \"new title\" .",
      [:append]
    )
  end
end
