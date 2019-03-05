defmodule Membrane.Element.AAC.Decoder do
  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw

  def_input_pads input: [
                   caps: :any,
                   demand_unit: :buffers
                 ]

  def_output_pads output: [
                    caps: {Raw, format: :s16le}
                  ]

  @impl true
  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil}}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <- Native.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_demand(:output, _size, :bytes, _ctx, state) do
    {{:ok, demand: :input}, state}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    to_decode = state.queue <> payload

    with {:ok, {next_frame, frame_size, sample_rate, channels}} <-
           Native.decode_frame(to_decode, state.native) do
      new_caps = %Raw{format: :s16le, sample_rate: sample_rate, channels: channels}

      caps_action = if ctx.pads.output.caps == new_caps, do: [], else: [caps: {:output, new_caps}]
      buffer_action = [buffer: {:output, %Buffer{payload: next_frame}}]

      {{:ok, caps_action ++ buffer_action ++ [redemand: :output]}, state}
    else
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end
end
