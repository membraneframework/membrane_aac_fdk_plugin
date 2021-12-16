defmodule Membrane.AAC.FDK.Plugin.MixProject do
  use Mix.Project

  @version "0.8.1"
  @github_url "https://github.com/membraneframework/membrane_aac_fdk_plugin"

  def project do
    [
      app: :membrane_aac_fdk_plugin,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Membrane AAC decoder and encoder based on FDK library",
      package: package(),
      name: "Membrane AAC FDK plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"]
    ]
  end

  defp deps do
    [
      {:membrane_core, "~> 0.7.0"},
      {:membrane_common_c, "~> 0.9.0"},
      {:bunch, "~> 1.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:unifex, "~> 0.7.0"},
      {:membrane_caps_audio_raw, "~> 0.4.0"},
      {:membrane_file_plugin, "~> 0.6.0", only: [:dev, :test]}
    ]
  end
end
