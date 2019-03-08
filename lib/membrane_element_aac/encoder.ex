defmodule Membrane.Element.AAC.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw

  @channels 2

  def_output_pads output: [
                    caps: :any
                  ]

  def_input_pads input: [
                   demand_unit: :bytes,
                   caps: {Raw, format: :s32le, sample_rate: 44_100, channels: @channels}
                 ]

  @impl true
  def handle_init(options) do
    {:ok, %{native: nil, options: options}}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <-
           Native.create(
             @channels,
             state.options.sample_rate,
             2
           ) do
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
  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_demand(:output, bufs, :buffers, _ctx, %{raw_frame_size: size} = state) do
    {{:ok, demand: {:input, size * bufs}}, state}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, _ctx, state) do
    %{native: native} = state

    with {:ok, {encoded_bufs}} <- Native.encode_frame(native, data) do
      {{:ok, buffer: {:output, encoded_bufs}}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end
end
