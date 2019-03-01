defmodule Membrane.Element.AAC.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      nifs: nifs(Bundlex.platform())
    ]
  end

  def nifs(_platform) do
    [
      decoder: [
        deps: [unifex: :unifex],
        sources: ["_generated/decoder.c", "decoder.c"],
        libs: ["fdk-aac"]
      ]
    ]
  end
end
