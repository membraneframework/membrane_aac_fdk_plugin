defmodule Encoder.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Element.AAC.Encoder.Native

  @channels 2
  @sample_rate 44_100
  @audio_object_type 2
  # CBR
  @bitrate_mode 0

  def prepare_paths(filename) do
    in_path = "fixtures/input-#{filename}.raw" |> Path.expand(__DIR__)
    reference_path = "fixtures/reference-#{filename}.aac" |> Path.expand(__DIR__)
    {in_path, reference_path}
  end

  def assert_frames_equal(encoded_frame, reference_frame) do
    assert bit_size(encoded_frame) == bit_size(reference_frame)
    assert Membrane.Payload.to_binary(encoded_frame) == reference_frame
  end

  describe "Native AAC Encoder should" do
    test "Encode 1 AAC frame" do
      {in_path, reference_path} = prepare_paths("encoder")

      assert {:ok, file} = File.read(in_path)

      assert {:ok, encoder_ref} =
               Native.create(@channels, @sample_rate, @audio_object_type, @bitrate_mode)

      assert <<frame::bytes-size(4096), _::binary>> = file
      assert {:ok, encoded_frame} = Native.encode_frame(frame, encoder_ref)

      assert {:ok, ref_file} = File.read(reference_path)

      assert <<ref_frame::bytes-size(8192), _::binary>> = ref_file

      assert_frames_equal(encoded_frame, ref_frame)
    end

    test "Encode single AAC frame if supplied with larger buffer" do
      {in_path, reference_path} = prepare_paths("encoder")

      assert {:ok, file} = File.read(in_path)

      assert {:ok, encoder_ref} =
               Native.create(@channels, @sample_rate, @audio_object_type, @bitrate_mode)

      assert <<frame::bytes-size(8192), _::binary>> = file
      assert {:ok, encoded_frame} = Native.encode_frame(frame, encoder_ref)

      assert {:ok, ref_file} = File.read(reference_path)

      assert <<ref_frame::bytes-size(8192), _::binary>> = ref_file

      assert_frames_equal(encoded_frame, ref_frame)
    end

    test "Return :no_data if frame is too small" do
      {in_path, _reference_path} = prepare_paths("encoder")

      assert {:ok, file} = File.read(in_path)

      assert {:ok, encoder_ref} =
               Native.create(@channels, @sample_rate, @audio_object_type, @bitrate_mode)

      assert <<frame::bytes-size(1024), _::binary>> = file
      assert {:error, :no_data} = Native.encode_frame(frame, encoder_ref)
    end
  end
end
