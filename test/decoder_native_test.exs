defmodule Decoder.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Element.AAC.Decoder.Native

  test "Decode 1 AAC frame" do
    in_path = "fixtures/input-sample.aac" |> Path.expand(__DIR__)
    reference_path = "fixtures/reference-sample.raw" |> Path.expand(__DIR__)

    assert {:ok, file} = File.read(in_path)
    assert {:ok, decoder_ref} = Native.create()

    assert <<frame::bytes-size(256), _::binary>> = file
    assert :ok = Native.fill(frame, decoder_ref)
    assert {:ok, decoded_frame} = Native.decode_frame(frame, decoder_ref)
    assert {:error, :not_enough_bits} = Native.decode_frame(frame, decoder_ref)

    assert {:ok, ref_file} = File.read(reference_path)

    assert <<ref_frame::bytes-size(4096), _::binary>> = ref_file

    assert bit_size(decoded_frame) == bit_size(ref_frame)
    assert Membrane.Payload.to_binary(decoded_frame) == ref_frame
  end
end
