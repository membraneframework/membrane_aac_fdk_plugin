defmodule Membrane.AAC.FDK.Decoder do
  @moduledoc """
  Element for decoding AAC audio to raw data in S16LE format.
  """

  use Bunch
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.RawAudio

  def_input_pad :input, accepted_format: _any, demand_mode: :auto

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
      {:error, reason} -> raise "Error: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
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
  # 3. Set output stream_format based on the stream metadata.
  # This should execute only once when output stream_format are not specified yet,
  # since they should stay consistent for the whole stream.
  # 4. In case an unhandled error is returned during this flow, returns error message.
  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    with :ok <- Native.fill(payload, state.native),
         {:ok, decoded_frames} <- decode_buffer(payload, state.native),
         {:ok, stream_format_action} <-
           get_stream_format_if_needed(ctx.pads.output.stream_format, state) do
      buffer_actions = [buffer: {:output, decoded_frames}]

      {stream_format_action ++ buffer_actions, state}
    else
      {:error, reason} ->
        raise "Error: #{inspect(reason)}"
    end
  end

  defp decode_buffer(payload, native, acc \\ []) do
    case Native.decode_frame(payload, native) do
      {:ok, decoded_frame} ->
        # Accumulate decoded frames
        decode_buffer(payload, native, [%Buffer{payload: decoded_frame} | acc])

      {:error, :not_enough_bits} ->
        # Means that we've parsed the whole buffer.
        {:ok, Enum.reverse(acc)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_stream_format_if_needed(nil, state) do
    {:ok, {_frame_size, sample_rate, channels}} = Native.get_metadata(state.native)

    {:ok,
     stream_format:
       {:output, %RawAudio{sample_format: :s16le, sample_rate: sample_rate, channels: channels}}}
  end

  defp get_stream_format_if_needed(_stream_format, _state), do: {:ok, []}
end
