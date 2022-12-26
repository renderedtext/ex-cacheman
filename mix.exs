defmodule ExCacheman.MixProject do
  use Mix.Project

  def project do
    [
      app: :cacheman,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 0.10.5"},
      {:mock, "~> 0.3.0", only: :test},
      {:poolboy, "~> 1.5"}
    ]
  end
end
