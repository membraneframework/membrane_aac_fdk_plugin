module Membrane.Element.AAC.Decoder.Native

spec create() :: {:ok :: label, state}
  | {:error :: label, :unknown :: label}
  | {:error :: label, :no_memory :: label}

spec decode_frame(payload, state) :: {:ok :: label, {payload}}
  | {:error :: label, :invalid_data :: label}
  | {:error :: label, :unknown :: label}
