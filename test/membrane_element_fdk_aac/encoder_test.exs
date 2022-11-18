defmodule Membrane.AAC.FDK.EncoderTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.AAC.FDK.Support.EncodingPipeline
  alias Membrane.Pipeline

  defp assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert byte_size(a) == byte_size(b)
    assert a == b
  end

  defp prepare_paths(filename, tmp_dir) do
    in_path = "test/fixtures/input-#{filename}.raw"
    reference_path = "test/fixtures/reference-#{filename}.aac"
    out_path = Path.join(tmp_dir, "output-encoding-#{filename}.aac")
    {in_path, reference_path, out_path}
  end

  @tag :tmp_dir
  describe "Encoding Pipeline should" do
    test "Encode AAC file", ctx do
      {in_path, reference_path, out_path} = prepare_paths("encoder", ctx.tmp_dir)
      assert pid = EncodingPipeline.make_pipeline(in_path, out_path)

      assert_end_of_stream(pid, :sink, :input, 3000)
      assert_files_equal(out_path, reference_path)
    end
  end
end
