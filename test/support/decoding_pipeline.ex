defmodule DecodingPipeline do
  @moduledoc false

  def get_options(%{in: in_path, out: out_path, pid: pid}) do
    %Membrane.Testing.Pipeline.Options{
      elements: [
        file_src: %Membrane.Element.File.Source{location: in_path},
        decoder: Membrane.Element.AAC.Decoder,
        sink: %Membrane.Element.File.Sink{location: out_path}
      ],
      monitored_callbacks: [:handle_notification],
      test_process: pid
    }
  end
end
