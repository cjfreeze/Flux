defmodule Flux.Mixfile do
  use Mix.Project

  def project do
    [
      app: :flux,
      version: "0.1.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      package: package(),
      deps: deps(),
      description: """
      A lightweight and functional http server designed from the ground up to work with plug.
      """
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      # extra_applications: [:logger],
      applications: [:logger],
      mod: {Flux.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.19.1", only: :dev},
      {:nexus, path: "../nexus"},
      {:httpoison, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.8", only: :test},
      {:websockex, "~> 0.4.0", only: :test},
      {:benchee, "~> 0.13.1", only: :dev},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end

  defp package do
    [
      maintainers: [
        "Chris Freeze"
      ],
      licenses: ["MIT"],
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      links: %{"GitHub" => "https://github.com/cjfreeze/flux"}
    ]
  end
end
