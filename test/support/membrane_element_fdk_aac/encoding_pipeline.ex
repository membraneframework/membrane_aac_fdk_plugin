defmodule Membrane.AAC.FDK.Support.EncodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  defmodule FormatProvider do
    @moduledoc false
    use Membrane.Filter

    def_options input_format: [
                  description:
                    "Format which will be sent on the :output pad once the :input pad receives any stream format info",
                  spec: struct()
                ]

    def_output_pad :output, accepted_format: Membrane.RawAudio
    def_input_pad :input, accepted_format: Membrane.RemoteStream

    @impl true
    def handle_stream_format(:input, _format, _ctx, state) do
      {[stream_format: {:output, state.input_format}], state}
    end

    @impl true
    def handle_buffer(:input, buffer, _ctx, state) do
      {[buffer: {:output, buffer}], state}
    end
  end

  @spec make_pipeline(Path.t(), Path.t()) :: pid()
  def make_pipeline(in_path, out_path) do
    import Membrane.ChildrenSpec

    Pipeline.start_link_supervised!(
      spec:
        child(:file_src, %Membrane.File.Source{location: in_path})
        |> child(:format_provider, %FormatProvider{
          input_format: %Membrane.RawAudio{
            sample_format: :s16le,
            channels: 2,
            sample_rate: 44_100
          }
        })
        |> child(:encoder, Membrane.AAC.FDK.Encoder)
        |> child(:sink, %Membrane.File.Sink{location: out_path})
    )
  end
end
