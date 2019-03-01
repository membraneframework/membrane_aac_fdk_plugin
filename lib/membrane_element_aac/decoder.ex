defmodule Membrane.Element.AAC.Filter do
  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Caps.Audio.Raw

  def_input_pads input: [
                   caps: :any,
                   demand_unit: :buffers
                 ]

  def_output_pads output: [
                    caps: {Raw, format: :s24le}
                  ]

  @impl true
  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    with {:ok, native} <- Native.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_demand(_output_pad, _size, _unit, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    to_decode = state.queue <> buffer.payload

    case decode_buffer(state.native, to_decode, ctx.pads.output.caps) do
      {:ok, {new_queue, actions}} ->
        {{:ok, actions ++ [redemand: :output]}, %{state | queue: new_queue}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp decode_buffer(native, buffer, caps, acc \\ [])

  defp decode_buffer(_native, <<>>, _caps, acc) do
    {:ok, {<<>>, Enum.reverse(acc)}}
  end

  defp decode_buffer(native, buffer, caps, acc) when byte_size(buffer) > 0 do
    with {:ok, {decoded_frame}} <- Native.decoded_frame(buffer, native) do
    end
  end
end
