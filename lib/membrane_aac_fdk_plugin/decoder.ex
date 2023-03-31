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

  def_input_pad(:input,
    demand_mode: :auto,
    accepted_format:
      any_of(AAC, %Membrane.RemoteStream{content_format: format} when format in [AAC, nil])
  )

  def_output_pad(:output, demand_mode: :auto, accepted_format: %RawAudio{sample_format: :s16le})

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{native: nil, next_pts: nil, stream_format: nil}}
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
  def handle_process(:input, %Buffer{pts: pts} = buffer, ctx, %{next_pts: nil} = state) do
    handle_process(:input, buffer, ctx, %{state | next_pts: pts})
  end

  def handle_process(:input, %Buffer{payload: payload}, ctx, %{next_pts: base_pts} = state) do
    :ok = Native.fill!(payload, state.native)
    decoded_buffers = decode_buffer!(payload, state.native)

    {format_actions, state} =
      get_output_format_action_if_needed(ctx.pads.output.stream_format, state)

    {buffers, next_pts} =
      Enum.map_reduce(decoded_buffers, base_pts, fn buffer, pts ->
        {%Buffer{buffer | pts: pts}, pts + RawAudio.frames_to_time(1, state.stream_format)}
      end)

    buffer_actions = [buffer: {:output, buffers}]
    state = %{state | next_pts: next_pts}

    {format_actions ++ buffer_actions, state}
  end

  defp decode_buffer!(payload, native, acc \\ []) do
    case Native.decode_frame(payload, native) do
      {:ok, decoded_frame} ->
        # Accumulate decoded frames
        decode_buffer!(payload, native, [%Buffer{payload: decoded_frame} | acc])

      {:error, :not_enough_bits} ->
        # Means that we've parsed the whole buffer.
        Enum.reverse(acc)

      {:error, reason} ->
        raise "Failed to decode frame: #{inspect(reason)}"
    end
  end

  defp get_output_format_action_if_needed(nil, state) do
    {:ok, {_frame_size, sample_rate, channels}} = Native.get_metadata(state.native)
    format = %RawAudio{sample_format: :s16le, sample_rate: sample_rate, channels: channels}
    {[stream_format: {:output, format}], %{state | stream_format: format}}
  end

  defp get_output_format_action_if_needed(_format, state) do
    {[], state}
  end
end
