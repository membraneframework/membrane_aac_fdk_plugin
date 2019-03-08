module Membrane.Element.AAC.Encoder.Native

# aot - Audio object type. See: https://github.com/mstorsjo/fdk-aac/blob/master/libAACenc/include/aacenc_lib.h#L1280
# - 2: MPEG-4 AAC Low Complexity.
# - 5: MPEG-4 AAC Low Complexity with Spectral Band Replication (HE-AAC).
# - 29: MPEG-4 AAC Low Complexity with Spectral Band Replication and Parametric Stereo (HE-AAC v2). This configuration can be used only with stereo input audio data.
# - 23: MPEG-4 AAC Low-Delay.
# - 39: MPEG-4 AAC Enhanced Low-Delay.
# - 129: MPEG-2 AAC Low Complexity.
# - 132: MPEG-2 AAC Low Complexity with Spectral Band Replication (HE-AAC).
spec create(
  channels :: int,
  sample_rate :: int,
  aot :: int
) :: {:ok :: label, state}
  | {:error :: label, reason :: atom}

spec encode_frame(payload, state) :: {:ok :: label, payload}
  | {:error :: label, reason :: atom}
