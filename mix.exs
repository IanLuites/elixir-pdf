defmodule PDF.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pdf,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"],
    ]
  end

  def application do
    [
      extra_applications: [:logger],
    ]
  end

  defp deps do
    [
      {:temp, "~> 0.1", git: "https://github.com/IanLuites/elixir-temp.git"},

      # TEST
      {:analyze, "~> 0.0", only: [:dev, :test], runtime: false, override: true},
      # {:meck, "~> 0.8", only: :test},
    ]
  end
end
