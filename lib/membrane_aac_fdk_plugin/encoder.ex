defmodule Membrane.AAC.FDK.Encoder do
  @moduledoc """
  Element encoding raw audio into AAC format
  """

  use Membrane.Filter

  import Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.AAC
  alias Membrane.Buffer
  alias Membrane.RawAudio

  # AAC Constants
  @sample_size 2

  # MPEG-4 AAC Low Complexity
  @default_audio_object_type :mpeg4_lc

  @allowed_aots [
    :mpeg4_lc,
    :mpeg4_he,
    :mpeg4_he_v2,
    :mpeg2_lc,
    :mpeg2_he
  ]

  @type allowed_aots :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_aots))

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

  @type allowed_sample_rates :: unquote(Bunch.Typespec.enum_to_alternative(@allowed_sample_rates))

  @allowed_bitrate_modes [0, 1, 2, 3, 4, 5]

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
                spec: RawAudio.t(),
                type: :stream_format,
                default: nil,
                description: """
                Input type - used to set input sample rate and channels.
                """
              ]

  def_output_pad :output, accepted_format: %AAC{encapsulation: :ADTS}

  def_input_pad :input,
    accepted_format:
      %RawAudio{sample_format: :s16le, sample_rate: rate} when rate in @allowed_sample_rates

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        native: nil,
        queue: <<>>,
        current_pts: nil
      })

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, format, _ctx, state) do
    native =
      mk_native!(
        format.channels,
        format.sample_rate,
        state.aot,
        state.bitrate_mode,
        state.bitrate
      )

    {profile, mpeg_version} =
      case state.aot do
        # TODO: Change when AAC format receives support for mpeg2 aot ids
        :mpeg2_lc -> {:LC, 2}
        :mpeg2_he -> {:HE, 2}
        mpeg4_aot -> {AAC.aot_id_to_profile(map_aot_to_value!(mpeg4_aot)), 4}
      end

    out_format = %AAC{
      profile: profile,
      sample_rate: format.sample_rate,
      channels: format.channels,
      mpeg_version: mpeg_version,
      encapsulation: :ADTS
    }

    {[stream_format: {:output, out_format}],
     %{state | native: native, input_stream_format: format}}
  end

  @impl true
  def handle_buffer(:input, %Buffer{payload: payload, pts: input_pts}, ctx, state) do
    %{native: native, queue: queue} = state

    to_encode = queue <> payload

    raw_frame_size =
      aac_frame_size(state.aot) * ctx.pads.input.stream_format.channels * @sample_size

    check_pts_integrity? = state.queue != <<>>

    state =
      if state.queue == <<>> do
        %{state | current_pts: input_pts}
      else
        state
      end

    case encode_buffer(to_encode, native, raw_frame_size, state) do
      {encoded_buffers, bytes_used, state} when bytes_used > 0 ->
        <<_handled::binary-size(bytes_used), rest::binary>> = to_encode

        cond do
          check_pts_integrity? and length(encoded_buffers) >= 2 and Enum.at(encoded_buffers, 1).pts > input_pts ->
            Membrane.Logger.warning("PTS values are overlapping")
          check_pts_integrity? and length(encoded_buffers) >= 2 and Enum.at(encoded_buffers, 1).pts < input_pts ->
            Membrane.Logger.warning("PTS values are not continous")
          true ->
            :ok
        end

        {[buffer: {:output, encoded_buffers}], %{state | queue: rest}}

      {[], 0, state} ->
        {[], %{state | queue: to_encode}}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    %{native: native, queue: queue} = state

    if queue != <<>>,
      do: warning("Processing queue is not empty, but EndOfStream event was received")

    actions = [end_of_stream: :output]

    with {:ok, encoded_frame} <- Native.encode_frame(<<>>, native) do
      buffer_actions = [buffer: {:output, %Buffer{payload: encoded_frame}}]

      {buffer_actions ++ actions, state}
    else
      {:error, :no_data} -> {actions, state}
      {:error, reason} -> raise "Failed to encode frame: #{inspect(reason)}"
    end
  end

  defp encode_buffer(buffer, native, raw_frame_size, acc \\ [], bytes_used \\ 0, state)

  # Encode a single frame if buffer contains at least one frame
  defp encode_buffer(buffer, native, raw_frame_size, acc, bytes_used, state)
       when byte_size(buffer) >= raw_frame_size do
    <<raw_frame::binary-size(raw_frame_size), rest::binary>> = buffer

    encoded_buffer = %Buffer{
      payload: Native.encode_frame!(raw_frame, native),
      pts: state.current_pts
    }

    # Continue encoding the rest until no more frames are available in the queue
    encode_buffer(
      rest,
      native,
      raw_frame_size,
      [encoded_buffer | acc],
      bytes_used + raw_frame_size,
      bump_current_pts(state, raw_frame)
    )
  end

  # Not enough samples for a frame
  defp encode_buffer(_partial_buffer, _native, _raw_frame_size, acc, bytes_used, state) do
    # Return accumulated encoded frames
    {acc |> Enum.reverse(), bytes_used, state}
  end

  defp bump_current_pts(%{current_pts: nil} = state, _raw_frame), do: state

  defp bump_current_pts(state, raw_frame) do
    duration =
      raw_frame
      |> byte_size()
      |> RawAudio.bytes_to_time(state.input_stream_format)

    Map.update!(state, :current_pts, &(&1 + duration))
  end

  defp mk_native!(channels, sample_rate, aot, bitrate_mode, bitrate) do
    :ok = validate_sample_rate!(sample_rate)
    :ok = validate_bitrate_mode!(bitrate_mode)
    aot = map_aot_to_value!(aot)

    Native.create(
      channels,
      sample_rate,
      aot,
      bitrate_mode,
      bitrate || 0
    )
    |> case do
      {:ok, native} -> native
      {:error, reason} -> raise "Failed to create native encoder: #{inspect(reason)}"
    end
  end

  # Frame size is 2 times larger for HE profiles.
  defp aac_frame_size(aot) when aot in [:mpeg4_he, :mpeg4_he_v2, :mpeg2_he], do: 2048
  defp aac_frame_size(_aot), do: 1024

  # Options validators

  defp map_aot_to_value!(:mpeg4_lc), do: 2
  defp map_aot_to_value!(:mpeg4_he), do: 5
  defp map_aot_to_value!(:mpeg4_he_v2), do: 29
  defp map_aot_to_value!(:mpeg2_lc), do: 129
  defp map_aot_to_value!(:mpeg2_he), do: 132
  defp map_aot_to_value!(aot), do: raise("Invalid aot: #{inspect(aot)}")

  defp validate_sample_rate!(sample_rate) when sample_rate in @allowed_sample_rates, do: :ok

  defp validate_sample_rate!(sample_rate) do
    raise "Invalid sample_rate: #{inspect(sample_rate)}"
  end

  defp validate_bitrate_mode!(bitrate_mode) when bitrate_mode in @allowed_bitrate_modes, do: :ok

  defp validate_bitrate_mode!(bitrate_mode) do
    raise "Invalid bitrate_mode: #{inspect(bitrate_mode)}"
  end
end
