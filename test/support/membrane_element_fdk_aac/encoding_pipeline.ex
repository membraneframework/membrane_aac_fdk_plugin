defmodule Membrane.Element.FDK.AAC.Support.EncodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  def make_pipeline(in_path, out_path, pid \\ self()) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.Element.File.Source{location: in_path},
        encoder: %Membrane.Element.FDK.AAC.Encoder{
          input_caps: %{sample_rate: 44_100, channels: 2}
        },
        sink: %Membrane.Element.File.Sink{location: out_path}
      ],
      monitored_callbacks: [:handle_notification],
      test_process: pid
    })
  end
end
