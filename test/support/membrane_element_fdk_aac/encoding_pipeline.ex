defmodule Membrane.AAC.FDK.Support.EncodingPipeline do
  @moduledoc false

  import Membrane.ChildrenSpec

  alias Membrane.Testing.Pipeline

  defmodule StreamFormatProvider do
    @moduledoc false
    use Membrane.Filter

    def_options input_stream_format: [
                  description:
                    "stream_format which will be sent on the :output pad once the :input pad receives any stream_format",
                  type: :stream_format
                ]

    def_output_pad :output, demand_mode: :auto, accepted_format: _any

    def_input_pad :input, demand_unit: :bytes, demand_mode: :auto, accepted_format: _any

    @impl true
    def handle_init(_ctx, opts) do
      {[], %{stream_format: opts.input_stream_format}}
    end

    @impl true
    def handle_stream_format(:input, _stream_format, _ctx, state) do
      {[stream_format: {:output, state.stream_format}], state}
    end

    @impl true
    def handle_process(:input, buffer, _ctx, state) do
      {[buffer: {:output, buffer}], state}
    end
  end

  @spec make_pipeline(Path.t(), Path.t()) :: GenServer.on_start()
  def make_pipeline(in_path, out_path) do
    structure = [
      child(:file_src, %Membrane.File.Source{location: in_path})
      |> child(:stream_format_provider, %StreamFormatProvider{
        input_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          channels: 2,
          sample_rate: 44_100
        }
      })
      |> child(:encoder, %Membrane.AAC.FDK.Encoder{
        input_stream_format: %{sample_rate: 44_100, channels: 2}
      })
      |> child(:sink, %Membrane.File.Sink{location: out_path})
    ]

    Pipeline.start_link(structure: structure)
  end
end
