defmodule Membrane.AAC.FDK.EncoderTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.Pipeline
  alias Membrane.AAC.FDK.Support.EncodingPipeline

  defp assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert a == b
  end

  defp prepare_paths(filename) do
    in_path = "test/fixtures/input-#{filename}.raw"
    reference_path = "test/fixtures/reference-#{filename}.aac"
    out_path = "/tmp/output-encoding-#{filename}.aac"
    File.rm(out_path)
    on_exit(fn -> File.rm(out_path) end)
    {in_path, reference_path, out_path}
  end

  describe "Encoding Pipeline should" do
    test "Encode AAC file" do
      {in_path, reference_path, out_path} = prepare_paths("encoder")
      assert {:ok, pid} = EncodingPipeline.make_pipeline(in_path, out_path)

      assert Pipeline.play(pid) == :ok
      assert_end_of_stream(pid, :sink, :input, 3000)
      Pipeline.stop_and_terminate(pid, blocking?: true)
      assert_files_equal(out_path, reference_path)
    end
  end
end
