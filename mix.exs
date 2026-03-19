defmodule DCATR.MixProject do
  use Mix.Project

  @scm_url "https://github.com/dcat-r/dcatr-ex"
  @spec_url "https://w3id.org/dcatr"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :dcatr,
      version: @version,
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
      aliases: aliases(),

      # Docs
      name: "DCAT-R.ex",
      docs: docs(),

      # Hex
      package: package(),
      description:
        "A framework for services over RDF repositories based on the DCAT-R vocabulary."
    ]
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @scm_url,
        "Specification" => @spec_url,
        "Changelog" => @scm_url <> "/blob/main/CHANGELOG.md"
      },
      files: ~w[lib priv mix.exs .formatter.exs VERSION *.md]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex],
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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false}
    ]
  end

  defp rdf_ex_dep(dep, version, opts \\ []) do
    case System.get_env("RDF_EX_PACKAGES_SRC") do
      "LOCAL" -> {dep, path: "../../../RDF.ex/src/#{dep}"}
      _ -> {dep, version, opts}
    end
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp docs do
    [
      main: "DCATR",
      source_url: @scm_url,
      source_ref: "v#{@version}",
      logo: "dcatr-logo.png",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: [
        {:"README.md", [title: "About"]},
        {:"CHANGELOG.md", [title: "CHANGELOG"]},
        {:"LICENSE.md", [title: "License"]}
      ],
      groups_for_modules: [
        Model: [
          DCATR.GraphResolver,
          DCATR.Element,
          DCATR.Directory,
          DCATR.Directory.Type,
          DCATR.Graph,
          DCATR.Dataset,
          DCATR.Repository,
          DCATR.Service,
          DCATR.ServiceData,
          DCATR.Service.Type,
          DCATR.Repository.Type,
          DCATR.ServiceData.Type
        ],
        "Graph types": [
          DCATR.DataGraph,
          DCATR.SystemGraph,
          DCATR.ManifestGraph,
          DCATR.ServiceManifestGraph,
          DCATR.RepositoryManifestGraph,
          DCATR.WorkingGraph
        ],
        Manifest: [
          DCATR.Manifest,
          DCATR.Manifest.Type,
          DCATR.Manifest.Loader,
          DCATR.Manifest.LoadPath,
          DCATR.Manifest.Generator,
          DCATR.Manifest.Cache,
          DCATR.Manifest.GraphExpansion
        ],
        Namespaces: [
          DCATR.NS,
          DCATR.NS.DCATR
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({startOnLoad: true})</script>
    """
  end

  defp before_closing_body_tag(:epub), do: ""

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
