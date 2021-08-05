defmodule Membrane.AAC.FDK.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  def natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        pkg_configs: ["fdk-aac"],
        preprocessor: Unifex
      ],
      encoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        pkg_configs: ["fdk-aac"],
        preprocessor: Unifex
      ]
    ]
  end
end
