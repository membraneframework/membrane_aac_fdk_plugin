defmodule Membrane.AAC.FDK.Decoder do
  @moduledoc """
  Element for decoding AAC audio to raw data in S16LE format.
  """

  use Bunch
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.AAC
  alias Membrane.Buffer
  alias Membrane.RawAudio

  require Membrane.Logger

  def_input_pad(:input,
    demand_mode: :auto,
    accepted_format:
      any_of(AAC, %Membrane.RemoteStream{content_format: format} when format in [AAC, nil])
  )

  def_output_pad(:output, demand_mode: :auto, accepted_format: %RawAudio{sample_format: :s16le})

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{native: Native.create!(), output_format_detected: false}}
  end

  @impl true
  @doc """
  Since we only accept buffers that carry one single frame, we're able to
  preserve pts information simply forwarding it.
  """
  def handle_stream_format(:input, %Membrane.RemoteStream{content_format: %AAC{frames_per_buffer: 1}}, _ctx, state) do
    {[], state}
  end

  def handle_stream_format(:input, %AAC{frames_per_buffer: 1}, _ctx, state) do
    {[], state}
  end

  def handle_stream_format(:input, format, _ctx, _state) do
    raise "Unsupported input frame format #{inspect format}"
  end

  @impl true
  def handle_process(:input, buffer, _ctx, %{output_format_detected: false} = state) do
    fill_decoder(buffer, state)
    buffer = decode_buffer(buffer, state)

    {:ok, {_frame_size, sample_rate, channels}} = Native.get_metadata(state.native)
    if sample_rate == 0 or channels == 0 do
      raise "Unable to detect AAC format"
    end

    format = %RawAudio{sample_format: :s16le, sample_rate: sample_rate, channels: channels}
    {[stream_format: {:output, format}, buffer: {:output, buffer}], %{state | output_format_detected: true}}
  end

  def handle_process(:input, buffer, _ctx, state) do
    fill_decoder(buffer, state)
    buffer = decode_buffer(buffer, state)
    {[buffer: {:output, buffer}], state}
  end

  defp fill_decoder(%Buffer{payload: payload}, %{native: native}) do
    :ok = Native.fill!(payload, native)
  end

  defp decode_buffer(%Buffer{payload: payload, pts: pts}, %{native: native}) do
    case Native.decode_frame(payload, native) do
      {:ok, decoded_frame} ->
        %Buffer{payload: decoded_frame, pts: pts}

      {:error, :not_enough_bits} ->
        raise "Not enough data to decode one complete AAC frame"
      {:error, reason} ->
        raise "Failed to decode frame: #{inspect(reason)}"
    end
  end
end
