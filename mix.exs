defmodule DCATR.MixProject do
  use Mix.Project

  def project do
    [
      app: :dcatr,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: [
        summary: [threshold: 92],
        ignore_modules: [
          DCATR.Utils,
          # Generated Grax.Schema.Registerable modules
          ~r/^Grax\.Schema\.Registerable\..*/,
          # RDF.Vocabulary.Namespace generated module
          DCATR.NS.DCATR,
          # Empty abstract schema
          DCATR.Element,
          # Exception modules
          DCATR.DuplicateGraphNameError,
          DCATR.GraphNotFoundError,
          DCATR.ManifestError,
          DCATR.Manifest.GeneratorError,
          DCATR.Manifest.LoadingError,
          # Mix tasks
          Mix.Tasks.Dcatr.Init,
          # Test support
          DCATR.Case,
          DCATR.TestData,
          DCATR.TestFactories
        ]
      ],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DCATR.Application, []}
    ]
  end

  defp deps do
    [
      rdf_ex_dep(:rdf, "~> 3.0"),
      rdf_ex_dep(:grax, "~> 0.6"),
      rdf_ex_dep(:dcat, "~> 0.1", only: [:dev, :test]),
      rdf_ex_dep(:rdf_xml, "~> 1.2", only: [:dev, :test]),
      rdf_ex_dep(:json_ld, "~> 1.0", only: [:dev, :test]),
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp rdf_ex_dep(dep, version, opts \\ []) do
    case System.get_env("RDF_EX_PACKAGES_SRC") do
      "LOCAL" -> {dep, [{:path, "../#{dep}"} | opts]}
      _ -> {dep, version, opts}
    end
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        check: :test
      ]
    ]
  end

  defp aliases do
    [
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --all-warnings --warnings-as-errors",
        "format --check-formatted",
        "test --cover --warnings-as-errors",
        "credo"
      ]
    ]
  end
end
