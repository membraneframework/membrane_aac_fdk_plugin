defmodule Membrane.Element.AAC.Filter do
  use Membrane.Element.Base.Filter
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
  def handle_process(_pad, _payload, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(_output_pad, _size, _unit, _ctx, state) do
    {:ok, state}
  end
end
