defmodule Membrane.AAC.FDK.Support.EncodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        encoder: %Membrane.AAC.FDK.Encoder{
          input_caps: %{sample_rate: 44_100, channels: 2}
        },
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end
end
