defmodule Membrane.AAC.FDK.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp get_fdk_aac_url() do
    url_prefix =
      "https://github.com/membraneframework-precompiled/precompiled_fdk_aac/releases/latest/download/fdk-aac"

    case Bundlex.get_target() do
      %{os: "linux"} ->
        {:precompiled, "#{url_prefix}_linux.tar.gz"}

      %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled, "#{url_prefix}_macos_intel.tar.gz"}

      %{architecture: "aarch64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled, "#{url_prefix}_macos_arm.tar.gz"}

      _other ->
        nil
    end
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
