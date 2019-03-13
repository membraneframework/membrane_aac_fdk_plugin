defmodule Membrane.Element.AAC.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Membrane.Element.Base.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Event.EndOfStream

  use Membrane.Log, tags: :membrane_element_aac

  @channels 2
  @sample_size 2
  @default_sample_rate 44_100
  @aac_frame_size 1024
  # TODO: 2 is for AAC LC, Add handling different AOTs
  @audio_object_type 2

  def_output_pads output: [
                    caps: :any
                  ]

  def_input_pads input: [
                   demand_unit: :bytes,
                   caps:
                     {Raw, format: :s16le, sample_rate: @default_sample_rate, channels: @channels}
                 ]

  @impl true
  def handle_init(options) do
    {:ok,
     %{
       native: nil,
       options: options,
       queue: <<>>
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, state) do
    with {:ok, native} <-
           Native.create(
             @channels,
             @default_sample_rate,
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
    %{native: native, queue: queue} = state

    to_encode = queue <> data

    with {:ok, {encoded_buffers, bytes_used}} when bytes_used > 0 <-
           encode_buffer(to_encode, native) do
      <<_handled::binary-size(bytes_used), rest::binary>> = to_encode

      buffer_actions = [buffer: {:output, encoded_buffers}]

      {{:ok, buffer_actions ++ [redemand: :output]}, %{state | queue: rest}}
    else
      {:ok, {[], 0}} -> {:ok, %{state | queue: to_encode}}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_event(:input, %EndOfStream{}, _ctx, state) do
    %{native: native, queue: queue} = state

    if queue != <<>>,
      do: warn("Processing queue is not empty, but EndOfStream event was received")

    actions = [event: {:output, %EndOfStream{}}, notify: {:end_of_stream, :input}]

    with {:ok, encoded_frame} <- Native.encode_frame(<<>>, native) do
      buffer_actions = [buffer: {:output, %Buffer{payload: encoded_frame}}]

      {{:ok, buffer_actions ++ actions}, state}
    else
      {:error, :no_data} ->
        {{:ok, actions}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def handle_event(pad, event, ctx, state) do
    super(pad, event, ctx, state)
  end

  # Initialize buffer encoding
  defp encode_buffer(buffer, native) do
    raw_frame_size = @aac_frame_size * @channels * @sample_size

    encode_buffer(buffer, native, [], 0, raw_frame_size)
  end

  # Encode a single frame if buffer contains at least one frame
  defp encode_buffer(buffer, native, acc, bytes_used, raw_frame_size)
       when byte_size(buffer) >= raw_frame_size do
    <<raw_frame::binary-size(raw_frame_size), rest::binary>> = buffer

    with {:ok, encoded_frame} <- Native.encode_frame(raw_frame, native) do
      encoded_buffer = %Buffer{payload: encoded_frame}

      # Continue encoding the rest until no more frames are available in the queue
      encode_buffer(
        rest,
        native,
        [encoded_buffer | acc],
        bytes_used + raw_frame_size,
        raw_frame_size
      )
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Not enough samples for a frame
  defp encode_buffer(_native, _partial_buffer, acc, bytes_used, _raw_frame_size) do
    # Return accumulated encoded frames
    {:ok, {acc |> Enum.reverse(), bytes_used}}
  end
end
