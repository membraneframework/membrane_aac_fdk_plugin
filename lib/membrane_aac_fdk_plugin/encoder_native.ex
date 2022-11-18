defmodule Membrane.AAC.FDK.Encoder.Native do
  @moduledoc false
  # Interface module for native AAC encoder.

  use Unifex.Loader

  @spec encode_frame!(binary(), reference()) :: binary()
  def encode_frame!(frame, native) do
    case encode_frame(frame, native) do
      {:ok, frame} -> frame
      {:error, reason} -> raise "Failed to encode frame: #{inspect(reason)}"
    end
  end
end
