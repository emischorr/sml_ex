defmodule Sml.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/emischorr/sml_ex"

  def project do
    [
      app: :sml_ex,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "SmlEx",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Decoder for SML (Smart Message Language) telegrams as sent by German " <>
      "electricity meters (eHZ, mME) on their optical interface."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "Sml",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      groups_for_modules: [
        Messages: ~r/^Sml\.Messages\./,
        "Low level": [Sml.Transport, Sml.Parser, Sml.Decoder, Sml.CRC16]
      ]
    ]
  end
end
