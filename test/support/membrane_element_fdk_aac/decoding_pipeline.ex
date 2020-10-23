defmodule Membrane.AAC.FDK.Support.DecodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.Element.File.Source{location: in_path},
        decoder: Membrane.AAC.FDK.Decoder,
        sink: %Membrane.Element.File.Sink{location: out_path}
      ]
    })
  end
end
