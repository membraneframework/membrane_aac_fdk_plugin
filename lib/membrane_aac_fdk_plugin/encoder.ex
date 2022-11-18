defmodule Membrane.AAC.FDK.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Bunch.Typespec
  use Membrane.Filter

  import Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.RawAudio

  # AAC Constants
  @sample_size 2

  @default_channels 2
  @default_sample_rate 44_100
  # MPEG-4 AAC Low Complexity
  @default_audio_object_type :mpeg4_lc
  @allowed_channels [1, 2]
  @allowed_aots [
    :mpeg4_lc,
    :mpeg4_he,
    :mpeg4_he_v2,
    :mpeg2_lc,
    :mpeg2_he
  ]
  @allowed_sample_rates [
    96_000,
    88_200,
    64_000,
    48_000,
    44_100,
    32_000,
    24_000,
    22_050,
    16_000,
    12_000,
    11_025,
    8000
  ]
  @allowed_bitrate_modes [0, 1, 2, 3, 4, 5]

  @type allowed_channels :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_channels))
  @type allowed_aots :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_aots))
  @type allowed_sample_rates :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_sample_rates))
  @type allowed_bitrate_modes ::
          unquote(Bunch.Typespec.enum_to_alternative(@allowed_bitrate_modes))

  def_options aot: [
                description: """
                Audio object type. See: https://github.com/mstorsjo/fdk-aac/blob/master/libAACenc/include/aacenc_lib.h#L1280
                2: MPEG-4 AAC Low Complexity.
                5: MPEG-4 AAC Low Complexity with Spectral Band Replication (HE-AAC).
                29: MPEG-4 AAC Low Complexity with Spectral Band Replication and Parametric Stereo (HE-AAC v2). This configuration can be used only with stereo input audio data.
                129: MPEG-2 AAC Low Complexity.
                132: MPEG-2 AAC Low Complexity with Spectral Band Replication (HE-AAC).
                """,
                type: :atom,
                spec: allowed_aots(),
                default: @default_audio_object_type
              ],
              bitrate_mode: [
                description: """
                Bitrate Mode. See: http://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC#Bitrate_Modes
                0 - Constant Bitrate (default).
                1-5 - Variable Bitrate
                """,
                type: :integer,
                spec: allowed_bitrate_modes(),
                default: 0
              ],
              bitrate: [
                description: """
                Bitrate in bits/s for CBR.
                If set to nil (default value), the bitrate will be estimated based on the number of channels and sample rate.
                See: https://trac.ffmpeg.org/wiki/Encode/AAC#fdk_cbr
                Note that for VBR this parameter is ignored.
                """,
                type: :integer,
                spec: pos_integer() | nil,
                default: nil
              ],
              input_stream_format: [
                description: """
                Stream_format for the input pad. If set to nil (default value),
                stream_format is assumed to be received through the pad. If explicitly set to some
                stream_format, it cannot be changed by stream_format received through the pad.
                """,
                type: :stream_format,
                spec: RawAudio.t() | nil,
                default: nil
              ]

  def_output_pad :output, demand_mode: :auto, accepted_format: _any

  def_input_pad :input,
    demand_unit: :bytes,
    demand_mode: :auto,
    accepted_format:
      %RawAudio{
        sample_format: :s16le,
        channels: channels,
        sample_rate: sample_rate
      }
      when channels in @allowed_channels and sample_rate in @allowed_sample_rates

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>
      })

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, %{input_stream_format: nil} = state), do: {[], state}

  def handle_setup(_ctx, state) do
    input_stream_format =
      Map.merge(
        %RawAudio{
          sample_format: :s16le,
          channels: @default_channels,
          sample_rate: @default_sample_rate
        },
        state.input_stream_format
      )

    with {:ok, native} <-
           mk_native(
             input_stream_format.channels,
             input_stream_format.sample_rate,
             state.aot,
             state.bitrate_mode,
             state.bitrate
           ) do
      {[], %{state | native: native, input_stream_format: input_stream_format}}
    else
      {:error, reason} -> raise "Error: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(
        :input,
        stream_format,
        _ctx,
        %{input_stream_format: input_stream_format} = state
      )
      when input_stream_format in [nil, stream_format] do
    with {:ok, native} <-
           mk_native(
             stream_format.channels,
             stream_format.sample_rate,
             state.aot,
             state.bitrate_mode,
             state.bitrate
           ) do
      {[stream_format: {:output, stream_format}],
       %{state | native: native, input_stream_format: stream_format}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_stream_format(:input, stream_format, _ctx, %{
        input_stream_format: stored_stream_format
      }) do
    raise """
    Received stream_format #{inspect(stream_format)} are different than defined in options #{inspect(stored_stream_format)}.
    If you want to allow converter to accept different input stream_format dynamically, use `nil` as input_stream_format.
    """
  end

  @impl true
  def handle_process_list(:input, buffers, _ctx, state) do
    %{native: native, queue: queue} = state

    data = buffers |> Enum.map(& &1.payload)
    to_encode = [queue | data] |> IO.iodata_to_binary()

    raw_frame_size = aac_frame_size(state.aot) * state.input_stream_format.channels * @sample_size

    with {:ok, {encoded_buffers, bytes_used}} when bytes_used > 0 <-
           encode_buffer(to_encode, native, raw_frame_size) do
      <<_handled::binary-size(bytes_used), rest::binary>> = to_encode

      {[buffer: {:output, encoded_buffers}], %{state | queue: rest}}
    else
      {:ok, {[], 0}} -> {[], %{state | queue: to_encode}}
      {:error, reason} -> raise "Error: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    %{native: native, queue: queue} = state

    if queue != <<>>,
      do: warn("Processing queue is not empty, but EndOfStream event was received")

    actions = [end_of_stream: :output, notify_parent: {:end_of_stream, :input}]

    with {:ok, encoded_frame} <- Native.encode_frame(<<>>, native) do
      buffer_actions = [buffer: {:output, %Buffer{payload: encoded_frame}}]

      {buffer_actions ++ actions, state}
    else
      {:error, :no_data} ->
        {actions, state}

      {:error, reason} ->
        raise "Error: #{inspect(reason)}"
    end
  end

  defp encode_buffer(buffer, native, raw_frame_size, acc \\ [], bytes_used \\ 0)

  # Encode a single frame if buffer contains at least one frame
  defp encode_buffer(buffer, native, raw_frame_size, acc, bytes_used)
       when byte_size(buffer) >= raw_frame_size do
    <<raw_frame::binary-size(raw_frame_size), rest::binary>> = buffer

    with {:ok, encoded_frame} <- Native.encode_frame(raw_frame, native) do
      encoded_buffer = %Buffer{payload: encoded_frame}

      # Continue encoding the rest until no more frames are available in the queue
      encode_buffer(
        rest,
        native,
        raw_frame_size,
        [encoded_buffer | acc],
        bytes_used + raw_frame_size
      )
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Not enough samples for a frame
  defp encode_buffer(_partial_buffer, _native, _raw_frame_size, acc, bytes_used) do
    # Return accumulated encoded frames
    {:ok, {acc |> Enum.reverse(), bytes_used}}
  end

  defp mk_native(channels, sample_rate, aot, bitrate_mode, bitrate) do
    with {:ok, channels} <- validate_channels(channels),
         {:ok, sample_rate} <- validate_sample_rate(sample_rate),
         {:ok, aot} <- map_aot_to_value(aot),
         {:ok, bitrate_mode} <- validate_bitrate_mode(bitrate_mode),
         {:ok, native} <-
           Native.create(
             channels,
             sample_rate,
             aot,
             bitrate_mode,
             bitrate || 0
           ) do
      {:ok, native}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Frame size is 2 times larger for HE profiles.
  defp aac_frame_size(aot) when aot in [:mpeg4_he, :mpeg4_he_v2, :mpeg2_he], do: 2048
  defp aac_frame_size(_aot), do: 1024

  # Options validators

  defp map_aot_to_value(:mpeg4_lc), do: {:ok, 2}
  defp map_aot_to_value(:mpeg4_he), do: {:ok, 5}
  defp map_aot_to_value(:mpeg4_he_v2), do: {:ok, 29}
  defp map_aot_to_value(:mpeg2_lc), do: {:ok, 129}
  defp map_aot_to_value(:mpeg2_he), do: {:ok, 132}
  defp map_aot_to_value(_aot), do: {:error, :invalid_aot}

  defp validate_channels(channels) when channels in @allowed_channels, do: {:ok, channels}
  defp validate_channels(_channels), do: {:error, :invalid_channels}

  defp validate_sample_rate(sample_rate) when sample_rate in @allowed_sample_rates,
    do: {:ok, sample_rate}

  defp validate_sample_rate(_sample_rate), do: {:error, :invalid_sample_rate}

  defp validate_bitrate_mode(bitrate_mode) when bitrate_mode in @allowed_bitrate_modes,
    do: {:ok, bitrate_mode}

  defp validate_bitrate_mode(_bitrate_mode), do: {:error, :invalid_bitrate_mode}
end
