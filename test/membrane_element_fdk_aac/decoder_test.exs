defmodule Membrane.Element.FDK.AAC.DecoderTest do
  use ExUnit.Case
  import Membrane.Testing.Pipeline.Assertions
  alias Membrane.Pipeline
  alias Membrane.Element.FDK.AAC.Support.DecodingPipeline

  def assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert a == b
  end

  def prepare_paths(filename) do
    in_path = "test/fixtures/input-#{filename}.aac"
    reference_path = "test/fixtures/reference-#{filename}.raw"
    out_path = "/tmp/output-decoding-#{filename}.raw"
    File.rm(out_path)
    on_exit(fn -> File.rm(out_path) end)
    {in_path, reference_path, out_path}
  end

  describe "Decoding Pipeline should" do
    test "Decode AAC file" do
      {in_path, reference_path, out_path} = prepare_paths("sample")
      assert {:ok, pid} = DecodingPipeline.make_pipeline(in_path, out_path)

      assert Pipeline.play(pid) == :ok
      assert_receive_message({:handle_notification, {{:end_of_stream, :input}, :sink}}, 3000)
      assert_files_equal(out_path, reference_path)
    end
  end
end
