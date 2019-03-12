defmodule Membrane.Element.AAC.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Event.EndOfStream

  @channels 2
  @sample_rate 44_100
  @aac_frame_size 1024
  # TODO: 2 is for AAC LC, Add handling different AOTs
  @audio_object_type 2

  def_output_pads output: [
                    caps: :any
                  ]

  def_input_pads input: [
                   demand_unit: :bytes,
                   caps: {Raw, format: :s32le, sample_rate: @sample_rate, channels: @channels}
                 ]

  @impl true
  def handle_init(_) do
    {:ok, %{native: nil}}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <-
           Native.create(
             @channels,
             @sample_rate,
             @audio_object_type
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
  def handle_demand(:output, bufs, :buffers, _ctx, state) do
    {{:ok, demand: {:input, @aac_frame_size * bufs}}, state}
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, _ctx, state) do
    %{native: native} = state

    with {:ok, encoded_frame} <- Native.encode_frame(data, native) do
      buffer_actions = [buffer: {:output, %Buffer{payload: encoded_frame}}]
      {{:ok, buffer_actions ++ [redemand: :output]}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_event(:input, %EndOfStream{}, _ctx, state) do
    %{native: native} = state

    with {:ok, encoded_frame} <- Native.encode_frame(nil, native) do
      buffer_actions = [buffer: {:output, %Buffer{payload: encoded_frame}}]
      actions = [event: {:output, %EndOfStream{}}, notify: {:end_of_stream, :input}]
      {{:ok, buffer_actions ++ actions}, state}
    else
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def handle_event(pad, event, ctx, state) do
    super(pad, event, ctx, state)
  end
end
