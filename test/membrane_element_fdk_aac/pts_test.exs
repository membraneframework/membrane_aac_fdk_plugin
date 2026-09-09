defmodule Membrane.FLAC.Parser.IntegrationTest do
  use ExUnit.Case, async: true
  import Membrane.Testing.Assertions
  alias Membrane.{Buffer, Pipeline, RawAudio, Testing, Time}

  @decoder_output_format %RawAudio{sample_format: :s16le, sample_rate: 44_100, channels: 2}
  # 1024 samples of concealment lookahead plus 15 ms of PCM limiter
  @decoder_delay RawAudio.frames_to_time(1685, @decoder_output_format)

  test "encode with timestamps" do
    pipeline = prepare_pts_test_pipeline(true)

    Enum.each(0..294, fn index ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})

      # every other buffer gets queued and concated with next one to be big enough, because of that we expect different pts than on input
      assert out_pts == (index * 2 * 1000) |> Time.nanoseconds()
    end)

    Pipeline.terminate(pipeline)
  end

  test "encode without timestamps" do
    pipeline = prepare_pts_test_pipeline(false)

    Enum.each(0..294, fn _index ->
      assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{pts: out_pts})
      assert out_pts == nil
    end)

    Pipeline.terminate(pipeline)
  end

  test "decode with timestamps" do
    pipeline = prepare_decoder_pts_test_pipeline(Time.seconds(1))

    assert_sink_stream_format(pipeline, :sink, @decoder_output_format)

    assert_sink_buffer(pipeline, :sink, %Buffer{pts: pts})
    assert pts == Time.seconds(1) - @decoder_delay

    Pipeline.terminate(pipeline)
  end

  test "decode without timestamps" do
    pipeline = prepare_decoder_pts_test_pipeline(nil)

    assert_sink_buffer(pipeline, :sink, %Buffer{pts: nil})

    Pipeline.terminate(pipeline)
  end

  defp prepare_decoder_pts_test_pipeline(pts) do
    import Membrane.ChildrenSpec

    payload = "../fixtures/input-sample.aac" |> Path.expand(__DIR__) |> File.read!()

    spec =
      child(:source, %Testing.Source{
        output: [%Buffer{payload: payload, pts: pts}],
        stream_format: %Membrane.RemoteStream{content_format: Membrane.AAC}
      })
      |> child(:decoder, Membrane.AAC.FDK.Decoder)
      |> child(:sink, Testing.Sink)

    Testing.Pipeline.start_link_supervised!(spec: spec)
  end

  defp prepare_pts_test_pipeline(with_pts?) do
    import Membrane.ChildrenSpec

    spec =
      child(:source, %Membrane.Testing.Source{
        output: buffers_from_file(with_pts?),
        stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 16_000,
          channels: 1
        }
      })
      |> child(:aac_encoder, Membrane.AAC.FDK.Encoder)
      |> child(:sink, Membrane.Testing.Sink)

    Membrane.Testing.Pipeline.start_link_supervised!(spec: spec)
  end

  defp buffers_from_file(with_pts?) do
    # 589 buffers is generated from this binary
    binary = "../fixtures/input-encoder.raw" |> Path.expand(__DIR__) |> File.read!()

    split_binary(binary)
    |> Enum.with_index()
    |> Enum.map(fn {payload, index} ->
      %Membrane.Buffer{
        payload: payload,
        pts:
          if with_pts? do
            (index * 1000) |> Time.nanoseconds()
          else
            nil
          end
      }
    end)
  end

  @spec split_binary(binary(), list(binary())) :: list(binary())
  def split_binary(binary, acc \\ [])

  def split_binary(<<binary::binary-size(1024), rest::binary>>, acc) do
    split_binary(rest, [binary] ++ acc)
  end

  def split_binary(rest, acc) when byte_size(rest) <= 1024 do
    Enum.reverse(acc) ++ [rest]
  end
end
