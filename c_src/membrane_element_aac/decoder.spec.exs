module Membrane.Element.AAC.Decoder.Native

spec create() :: {:ok :: label, state}
  | {:error :: label, :unknown :: label}
  | {:error :: label, :no_memory :: label}

spec get_metadata(state) :: {:ok, {frame_size :: long, sample_rate :: long, channels :: int}}

spec fill(payload, state) :: (:ok :: label)
  | {:error :: label, :invalid_data :: label}

spec decode_frame(payload, state) :: {:ok :: label, payload}
  | {:error :: label, :not_enough_bits :: label}
  | {:error :: label, :unknown :: label}
