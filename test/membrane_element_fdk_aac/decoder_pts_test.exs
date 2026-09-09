defmodule Membrane.AAC.FDK.Decoder.PtsTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, RawAudio, Testing, Time}

  @output_format %RawAudio{sample_format: :s16le, sample_rate: 44_100, channels: 2}
  # 1024 samples of concealment lookahead plus 15 ms of PCM limiter attack
  @decoder_delay RawAudio.frames_to_time(1685, @output_format)

  test "output pts is shifted back by the decoder delay" do
    pipeline = start_pipeline(Time.seconds(1))

    assert_sink_stream_format(pipeline, :sink, @output_format)

    assert_sink_buffer(pipeline, :sink, %Buffer{pts: pts})
    assert pts == Time.seconds(1) - @decoder_delay

    Testing.Pipeline.terminate(pipeline)
  end

  test "output pts stays nil when input has no pts" do
    pipeline = start_pipeline(nil)

    assert_sink_buffer(pipeline, :sink, %Buffer{pts: nil})

    Testing.Pipeline.terminate(pipeline)
  end

  defp start_pipeline(pts) do
    payload = File.read!("test/fixtures/input-sample.aac")

    spec =
      child(:source, %Testing.Source{
        output: [%Buffer{payload: payload, pts: pts}],
        stream_format: %Membrane.RemoteStream{content_format: Membrane.AAC}
      })
      |> child(:decoder, Membrane.AAC.FDK.Decoder)
      |> child(:sink, Testing.Sink)

    Testing.Pipeline.start_link_supervised!(spec: spec)
  end
end
