module Membrane.AAC.FDK.Encoder.Native

state_type "State"

spec create(
  channels :: int,
  sample_rate :: int,
  aot :: int,
  bitrate_mode :: int,
  bitrate :: int
) :: {:ok :: label, state}
  | {:error :: label, reason :: atom}

spec encode_frame(payload, state) :: {:ok :: label, payload}
  | {:error :: label, reason :: atom}
  | {:error :: label, :no_data :: label}

dirty :cpu, [:create, :encode_frame]
