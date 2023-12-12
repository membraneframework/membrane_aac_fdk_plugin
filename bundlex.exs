defmodule Membrane.AAC.FDK.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        os_deps: [
          "fdk-aac": [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:"fdk-aac")},
            :pkg_config
          ]
        ],
        preprocessor: Unifex
      ],
      encoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        os_deps: [
          "fdk-aac": [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:"fdk-aac")},
            :pkg_config
          ]
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
