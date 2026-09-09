defmodule Membrane.AAC.FDK.Decoder do
  @moduledoc """
  Element for decoding AAC audio to raw data in S16LE format.

  The FDK decoder delays its output by a stream dependent number of samples
  (frame concealment lookahead, PCM limiter attack, SBR). The element
  compensates for it by shifting the timestamps of output buffers back by that
  delay, so a buffer's `pts` describes the samples it actually contains.
  """

  use Bunch
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.AAC
  alias Membrane.Buffer
  alias Membrane.RawAudio

  def_input_pad :input,
    accepted_format:
      any_of(
        %AAC{encapsulation: :ADTS},
        %Membrane.RemoteStream{content_format: format} when format in [AAC, nil]
      )

  def_output_pad :output, accepted_format: %RawAudio{sample_format: :s16le}

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{native: nil, pts_offset: nil}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    {[], %{state | native: Native.create!()}}
  end

  @impl true
  def handle_stream_format(:input, _format, _ctx, state) do
    {[], state}
  end

  # Handles parsing buffer payload to raw audio frames.
  #
  # The flow is as follows:
  # 1. Fill the native buffer using `Native.fill!` with input buffer content
  # 2. Natively decode audio frames using `Native.decode_frame`.
  # Since the input buffer can contain more than one frame,
  # we're calling `decode_frame` until it returns `:not_enough_bits`
  # to ensure we're emptying the whole native buffer.
  # 3. Set output format based on the stream metadata.
  # This should execute only once when output format are not specified yet,
  # since they should stay consistent for the whole stream.
  # 4. In case an unhandled error is returned during this flow, returns error message.
  @impl true
  def handle_buffer(:input, %Buffer{payload: payload, pts: pts}, ctx, state) do
    :ok = Native.fill!(payload, state.native)
    decoded_frames = decode_buffer!(payload, state.native)

    {format_action, state} =
      get_format_if_needed(ctx.pads.output.stream_format, decoded_frames, state)

    buffers =
      Enum.map(decoded_frames, &%Buffer{payload: &1, pts: shift_pts(pts, state.pts_offset)})

    {format_action ++ [buffer: {:output, buffers}], state}
  end

  defp decode_buffer!(payload, native, acc \\ []) do
    case Native.decode_frame(payload, native) do
      {:ok, decoded_frame} ->
        decode_buffer!(payload, native, [decoded_frame | acc])

      {:error, :not_enough_bits} ->
        # Means that we've parsed the whole buffer.
        Enum.reverse(acc)

      {:error, reason} ->
        raise "Failed to decode frame: #{inspect(reason)}"
    end
  end

  # Stream info is only valid once the decoder has produced a frame.
  defp get_format_if_needed(nil, [_frame | _rest], state) do
    {:ok, {_frame_size, sample_rate, channels, output_delay}} =
      Native.get_metadata(state.native)

    format = %RawAudio{sample_format: :s16le, sample_rate: sample_rate, channels: channels}
    pts_offset = RawAudio.frames_to_time(output_delay, format)

    {[stream_format: {:output, format}], %{state | pts_offset: pts_offset}}
  end

  defp get_format_if_needed(_format, _frames, state), do: {[], state}

  defp shift_pts(nil, _offset), do: nil
  defp shift_pts(pts, offset), do: pts - offset
end
