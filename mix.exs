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

  def application do
    [
      # extra_applications: [:logger],
      applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.19.1", only: :dev},
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
