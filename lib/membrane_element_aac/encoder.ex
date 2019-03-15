defmodule Membrane.Element.AAC.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Membrane.Element.Base.Filter
  use Bunch.Typespec
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Caps.Matcher
  alias Membrane.Event.EndOfStream

  use Membrane.Log, tags: :membrane_element_aac

  # AAC Constants
  @aac_frame_size 1024
  @sample_size 2

  @default_channels 2
  @default_sample_rate 44_100
  # MPEG-4 AAC Low Complexity
  @default_audio_object_type 2
  @list_type allowed_channels :: [1, 2]
  @list_type allowed_aots :: [2, 5, 29, 23, 39, 129, 132]
  @list_type allowed_sample_rates :: [
               96000,
               88200,
               64000,
               48000,
               44100,
               32000,
               24000,
               22050,
               16000,
               12000,
               11025,
               8000
             ]

  @supported_caps {Raw,
                   format: :s16le,
                   channels: Matcher.one_of(@allowed_channels),
                   sample_rate: Matcher.one_of(@allowed_sample_rates)}

  def_options aot: [
                description: """
                Audio object type. See: https://github.com/mstorsjo/fdk-aac/blob/master/libAACenc/include/aacenc_lib.h#L1280
                2: MPEG-4 AAC Low Complexity.
                5: MPEG-4 AAC Low Complexity with Spectral Band Replication (HE-AAC).
                29: MPEG-4 AAC Low Complexity with Spectral Band Replication and Parametric Stereo (HE-AAC v2). This configuration can be used only with stereo input audio data.
                23: MPEG-4 AAC Low-Delay.
                39: MPEG-4 AAC Enhanced Low-Delay.
                129: MPEG-2 AAC Low Complexity.
                132: MPEG-2 AAC Low Complexity with Spectral Band Replication (HE-AAC).
                """,
                type: :integer,
                spec: allowed_aots(),
                default: @default_audio_object_type
              ],
              input_caps: [
                description: """
                Caps for the input pad. If set to nil (default value),
                caps are assumed to be received through the pad. If explicitly set to some
                caps, they cannot be changed by caps received through the pad.
                """,
                type: :caps,
                spec: Raw.t() | nil,
                default: nil
              ]

  def_output_pads output: [
                    caps: :any
                  ]

  def_input_pads input: [
                   demand_unit: :bytes,
                   caps: @supported_caps
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
  def handle_stopped_to_prepared(_ctx, %{options: %{input_caps: nil}} = state), do: {:ok, state}

  def handle_stopped_to_prepared(_ctx, state) do
    input_caps =
      Map.merge(
        %Raw{format: :s16le, channels: @default_channels, sample_rate: @default_sample_rate},
        state.options.input_caps
      )

    with {:ok, native} <-
           mk_native(input_caps.channels, input_caps.sample_rate, state.options.aot) do
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
  def handle_caps(:input, caps, _ctx, %{options: %{input_caps: input_caps}} = state)
      when input_caps in [nil, caps] do
    with {:ok, native} <- mk_native(caps.channels, caps.sample_rate, state.options.aot) do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_caps(:input, caps, _ctx, %{input_caps: stored_caps}) do
    raise """
    Received caps #{inspect(caps)} are different then defined in options #{inspect(stored_caps)}.
    If you want to allow converter to accept different input caps dynamically, use `nil` as input_caps.
    """
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
    raw_frame_size = @aac_frame_size * @default_channels * @sample_size

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

  defp mk_native(channels, sample_rate, aot) do
    with {:ok, channels} <- validate_channels(channels),
         {:ok, sample_rate} <- validate_sample_rate(sample_rate),
         {:ok, aot} <- validate_aot(aot),
         {:ok, native} <-
           Native.create(
             channels,
             sample_rate,
             aot
           ) do
      {:ok, native}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Options validators

  defp validate_aot(aot) when aot in @allowed_aots, do: {:ok, aot}
  defp validate_aot(_), do: {:error, :invalid_aot}

  defp validate_channels(channels) when channels in @allowed_channels, do: {:ok, channels}
  defp validate_channels(_), do: {:error, :invalid_channels}

  defp validate_sample_rate(sample_rate) when sample_rate in @allowed_sample_rates,
    do: {:ok, sample_rate}

  defp validate_sample_rate(_), do: {:error, :invalid_sample_rate}
end
