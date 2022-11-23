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

  def_input_pad :input, accepted_format: any_of(Membrane.RemoteStream, AAC), demand_mode: :auto

  def_output_pad :output, accepted_format: %RawAudio{sample_format: :s16le}, demand_mode: :auto

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{native: nil}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    with {:ok, native} <- Native.create() do
      {[], %{state | native: native}}
    else
      {:error, reason} -> raise "Cannot create native decoder: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, _format, _ctx, state) do
    {[], state}
  end

  # Handles parsing buffer payload to raw audio frames.
  #
  # The flow is as follows:
  # 1. Fill the native buffer using `Native.fill` with input buffer content
  # 2. Natively decode audio frames using `Native.decode_frame`.
  # Since the input buffer can contain more than one frame,
  # we're calling `decode_frame` until it returns `:not_enough_bits`
  # to ensure we're emptying the whole native buffer.
  # 3. Set output format based on the stream metadata.
  # This should execute only once when output format are not specified yet,
  # since they should stay consistent for the whole stream.
  # 4. In case an unhandled error is returned during this flow, returns error message.
  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    :ok = Native.fill!(payload, state.native)
    decoded_frames = decode_buffer(payload, state.native)

    format_action = get_format_if_needed(ctx.pads.output.stream_format, state)
    buffer_actions = [buffer: {:output, decoded_frames}]

    {format_action ++ buffer_actions, state}
  end

  defp decode_buffer(payload, native, acc \\ []) do
    case Native.decode_frame(payload, native) do
      {:ok, decoded_frame} ->
        # Accumulate decoded frames
        decode_buffer(payload, native, [%Buffer{payload: decoded_frame} | acc])

      {:error, :not_enough_bits} ->
        # Means that we've parsed the whole buffer.
        Enum.reverse(acc)

      {:error, reason} ->
        raise "Failed to decode frame: #{inspect(reason)}"
    end
  end

  defp get_format_if_needed(nil, state) do
    {:ok, {_frame_size, sample_rate, channels}} = Native.get_metadata(state.native)

    [
      stream_format:
        {:output, %RawAudio{sample_format: :s16le, sample_rate: sample_rate, channels: channels}}
    ]
  end

  defp get_format_if_needed(_format, _state), do: []
end
