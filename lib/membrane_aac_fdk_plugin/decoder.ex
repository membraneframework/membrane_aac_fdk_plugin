defmodule Membrane.AAC.FDK.Decoder do
  @moduledoc """
  Element for decoding AAC audio to raw data in S16LE format.
  """

  use Bunch
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw

  def_input_pad :input, caps: :any, demand_mode: :auto

  def_output_pad :output, caps: {Raw, format: :s16le}, demand_mode: :auto

  @impl true
  def handle_init(_opts) do
    {:ok, %{native: nil}}
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
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, %{state | native: nil}}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  # Handles parsing buffer payload to raw audio frames.
  #
  # The flow is as follows:
  # 1. Fill the native buffer using `Native.fill` with input buffer content
  # 2. Natively decode audio frames using `Native.decode_frame`.
  # Since the input buffer can contain more than one frame,
  # we're calling `decode_frame` until it returns `:not_enough_bits`
  # to ensure we're emptying the whole native buffer.
  # 3. Set output caps based on the stream metadata.
  # This should execute only once when output caps are not specified yet,
  # since they should stay consistent for the whole stream.
  # 4. In case an unhandled error is returned during this flow, returns error message.
  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    with :ok <- Native.fill(payload, state.native),
         {:ok, decoded_frames} <- decode_buffer(payload, state.native),
         {:ok, caps_action} <- get_caps_if_needed(ctx.pads.output.caps, state) do
      buffer_actions = [buffer: {:output, decoded_frames}]

      {{:ok, caps_action ++ buffer_actions}, state}
    else
      {:error, reason} ->
        {{:error, reason}, state}
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

  defp get_caps_if_needed(nil, state) do
    {:ok, {_frame_size, sample_rate, channels}} = Native.get_metadata(state.native)
    {:ok, caps: {:output, %Raw{format: :s16le, sample_rate: sample_rate, channels: channels}}}
  end

  defp get_caps_if_needed(_caps, _state), do: {:ok, []}
end
