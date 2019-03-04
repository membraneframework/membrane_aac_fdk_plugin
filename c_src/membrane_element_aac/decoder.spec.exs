module Membrane.Element.AAC.Decoder.Native

spec create() :: {:ok :: label, state}
  | {:error :: label, :unknown :: label}
  | {:error :: label, :no_memory :: label}

spec decode_frame(payload, state) :: {:ok :: label, {payload, frame_size :: long, sample_rate :: long, channels :: int}}
  | {:error :: label, :invalid_data :: label}
  | {:error :: label, :not_enough_bits :: label}
  | {:error :: label, :unknown :: label}
