defmodule Membrane.AAC.FDK.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp get_fdk_aac_url() do
    system_architecture =
      case Bundlex.get_target() do
        %{os: "linux"} -> "linux"
        %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} -> "macos_intel"
        %{architecture: "aarch64", os: "darwin" <> _rest_of_os_name} -> "macos_m1"
        _other -> nil
      end

    {:precompiled,
     "https://github.com/membraneframework-precompiled/precompiled_fdk_aac/releases/latest/download/fdk-aac_#{system_architecture}.tar.gz"}
  end

  def natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        os_deps: [{get_fdk_aac_url(), "fdk-aac"}],
        preprocessor: Unifex
      ],
      encoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        os_deps: [{get_fdk_aac_url(), "fdk-aac"}],
        preprocessor: Unifex
      ]
    ]
  end
end
