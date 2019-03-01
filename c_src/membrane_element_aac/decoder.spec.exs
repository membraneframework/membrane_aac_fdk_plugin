module Membrane.Element.AAC.Decoder.Native

spec create() :: {:ok :: label, state}

spec decode_frame(payload, state) :: {:ok :: label}
