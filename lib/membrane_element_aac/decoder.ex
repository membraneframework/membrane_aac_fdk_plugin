defmodule Membrane.Element.AAC.Decoder do
  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  use Bunch

  def_input_pads input: [
                   caps: :any,
                   demand_unit: :buffers
                 ]

  def_output_pads output: [
                    caps: {Raw, format: :s16le}
                  ]

  @impl true
  def handle_init(_) do
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

      {{:ok, caps_action ++ buffer_actions ++ [redemand: :output]}, state}
    else
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp decode_buffer(payload, native, acc \\ [])

  defp decode_buffer(payload, native, acc) do
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

  defp get_caps_if_needed(_, _), do: {:ok, []}
end
