defmodule Membrane.AAC.FDK.Support.EncodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  defmodule CapsProvider do
    use Membrane.Filter

    def_options input_caps: [
                  description:
                    "Caps which will be sent on the :output pad once the :input pad receives any caps",
                  type: :caps
                ]

    def_output_pad :output, demand_mode: :auto, caps: :any

    def_input_pad :input, demand_unit: :bytes, demand_mode: :auto, caps: :any

    @impl true
    def handle_init(opts) do
      {:ok, %{caps: opts.input_caps}}
    end

    @impl true
    def handle_caps(:input, caps, _ctx, state) do
      {{:ok, caps: {:output, state.caps}}, state}
    end

    @impl true
    def handle_process(:input, buffer, _ctx, state ) do
      {{:ok, buffer: {:output, buffer}}, state}
    end
  end

  @spec make_pipeline(Path.t(), Path.t()) :: GenServer.on_start()
  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        caps_provider: %CapsProvider{
          input_caps: %Membrane.RawAudio{
            sample_format: :s16le,
            channels: 2,
            sample_rate: 44_100
          }
        },
        encoder: %Membrane.AAC.FDK.Encoder{
          input_caps: %{sample_rate: 44_100, channels: 2}
        },
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end
end
