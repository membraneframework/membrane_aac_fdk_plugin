defmodule Membrane.AAC.FDK.PipelineTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.AAC.FDK.Support.{DecodingPipeline, EncodingPipeline}

  defp assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert a == b
  end

  defp prepare_paths(file_in, file_out, tmp_dir) do
    in_path = "test/fixtures/input-#{file_in}"
    reference_path = "test/fixtures/reference-#{file_out}"
    out_path = Path.join(tmp_dir, file_out)
    {in_path, reference_path, out_path}
  end

  defp test_file(pipeline, file_in, file_out, %{tmp_dir: tmp_dir}) do
    {in_path, reference_path, out_path} = prepare_paths(file_in, file_out, tmp_dir)
    assert pid = pipeline.make_pipeline(in_path, out_path)

    assert_end_of_stream(pid, :sink, :input, 3000)
    assert_files_equal(out_path, reference_path)
  end

  describe "As part of the pipeline" do
    @describetag :tmp_dir

    test "Encoder must encode file", ctx do
      test_file(EncodingPipeline, "encoder.raw", "encoder.aac", ctx)
    end

    test "Decoder must decoder file", ctx do
      test_file(DecodingPipeline, "sample.aac", "sample.raw", ctx)
    end
  end
end
