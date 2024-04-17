defmodule Membrane.FLAC.Parser.IntegrationTest do
  use ExUnit.Case, async: true
  import Membrane.Testing.Assertions
  alias Membrane.{Pipeline, Time}

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
