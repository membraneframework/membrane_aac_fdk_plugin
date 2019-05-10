defmodule Membrane.Element.FDK.AAC.Decoder.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Element.FDK.AAC.Decoder.Native

  def prepare_paths(filename) do
    in_path = "test/fixtures/input-#{filename}.aac"
    reference_path = "test/fixtures/reference-#{filename}.raw"
    {in_path, reference_path}
  end

  def assert_frames_equal(decoded_frame, reference_frame) do
    assert bit_size(decoded_frame) == bit_size(reference_frame)
    assert Membrane.Payload.to_binary(decoded_frame) == reference_frame
  end

  describe "Native AAC Decoder should" do
    test "Decode 1 AAC frame" do
      {in_path, reference_path} = prepare_paths("sample")

      assert {:ok, file} = File.read(in_path)
      assert {:ok, decoder_ref} = Native.create()

      assert <<frame::bytes-size(256), _::binary>> = file
      assert :ok = Native.fill(frame, decoder_ref)
      assert {:ok, decoded_frame} = Native.decode_frame(frame, decoder_ref)
      assert {:error, :not_enough_bits} = Native.decode_frame(frame, decoder_ref)

      assert {:ok, ref_file} = File.read(reference_path)

      assert <<ref_frame::bytes-size(4096), _::binary>> = ref_file

      assert_frames_equal(decoded_frame, ref_frame)
    end

    test "Decode multiple AAC frames" do
      {in_path, reference_path} = prepare_paths("sample")

      assert {:ok, file} = File.read(in_path)
      assert {:ok, decoder_ref} = Native.create()

      assert <<frame::bytes-size(1024), _::binary>> = file
      assert :ok = Native.fill(frame, decoder_ref)
      assert {:ok, decoded_frame1} = Native.decode_frame(frame, decoder_ref)
      assert {:ok, decoded_frame2} = Native.decode_frame(frame, decoder_ref)
      assert {:ok, decoded_frame3} = Native.decode_frame(frame, decoder_ref)
      assert {:ok, decoded_frame4} = Native.decode_frame(frame, decoder_ref)
      assert {:error, :not_enough_bits} = Native.decode_frame(frame, decoder_ref)

      assert {:ok, ref_file} = File.read(reference_path)

      assert <<ref_frame1::bytes-size(4096), ref_frame2::bytes-size(4096),
               ref_frame3::bytes-size(4096), ref_frame4::bytes-size(4096), _::binary>> = ref_file

      assert_frames_equal(decoded_frame1, ref_frame1)
      assert_frames_equal(decoded_frame2, ref_frame2)
      assert_frames_equal(decoded_frame3, ref_frame3)
      assert_frames_equal(decoded_frame4, ref_frame4)
    end

    test "Decode chunked AAC frame" do
      {in_path, reference_path} = prepare_paths("sample")

      assert {:ok, file} = File.read(in_path)
      assert {:ok, decoder_ref} = Native.create()

      assert <<chunk1::bytes-size(128), chunk2::bytes-size(128), _::binary>> = file

      assert :ok = Native.fill(chunk1, decoder_ref)
      # First chunk does not contain a full frame
      assert {:error, :not_enough_bits} = Native.decode_frame(chunk1, decoder_ref)

      assert :ok = Native.fill(chunk2, decoder_ref)
      # Only after the second chunk is filled we can decode the frame
      assert {:ok, decoded_frame} = Native.decode_frame(chunk2, decoder_ref)
      assert {:ok, ref_file} = File.read(reference_path)

      assert <<ref_frame::bytes-size(4096), _::binary>> = ref_file

      assert_frames_equal(decoded_frame, ref_frame)
    end
  end
end
