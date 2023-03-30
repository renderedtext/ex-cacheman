defmodule ExCacheman.MixProject do
  use Mix.Project

  def project do
    [
      app: :cacheman,
      version: "0.1.0",
      elixir: "~> 1.11",
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
      {:redix, "~> 1.2.0"},
      {:poolboy, "~> 1.5"}
    ]
  end
end
