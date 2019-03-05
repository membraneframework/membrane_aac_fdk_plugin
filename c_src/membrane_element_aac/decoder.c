#include "decoder.h"

/**
 * AAC Decoder implementation.
 * Heavily inspired by https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/libfdk-aacdec.c
 */

#define DECODER_MAX_CHANNELS 8
#define DECODER_BUFFSIZE 2048 * sizeof(INT_PCM)

/**
 * Initializes AAC Decoder and returns State resource.
 * 
 * On success, returns {:ok, decoder_state}
 * In case of error, returns:
 * - {:error, :unknown} - If AAC decoder cannot be initialized
 * - {:error, :no_memory} - If there's not enough memory to initialize AAC buffer
 */
UNIFEX_TERM create(UnifexEnv *env) {
  State *state = unifex_alloc_state(env);

  state->handle = aacDecoder_Open(TT_MP4_ADTS, 1);

  if (!state->handle) {
    MEMBRANE_WARN(env, "AAC: Could not initialize decoder\n");
    return create_result_error_unknown(env);
  }

  state->decoder_buffer_size = DECODER_BUFFSIZE * DECODER_MAX_CHANNELS;
  state->decoder_buffer = unifex_alloc(state->decoder_buffer_size);

  if (!state->decoder_buffer) {
    return create_result_error_no_memory(env);
  }

  UNIFEX_TERM res = create_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

/**
 * Decodes one input frame.
 * 
 * Expects:
 * - Buffer to decode
 * - Native resource
 * as arguments
 * 
 * Returns one of:
 * - {:ok, {decoded_frame, frame_size, sample_rate, channels}}
 *    decoded audio frame with stream info
 * - {:error, :invalid_data}
 * - {:error, :not_enough_bits}
 * - {:error, :unknown}
 */
UNIFEX_TERM decode_frame(UnifexEnv *env, UnifexPayload *in_payload, State *state) {
  UNIFEX_TERM res;
  AAC_DECODER_ERROR err;
  UINT valid = in_payload->size;

  err = aacDecoder_Fill(
      state->handle,
      &in_payload->data,
      &in_payload->size,
      &valid);
  if (err != AAC_DEC_OK) {
    MEMBRANE_WARN(env, "AAC: aacDecoder_Fill() failed: %x\n", err);
    return decode_frame_result_error_invalid_data(env);
  }

  err = aacDecoder_DecodeFrame(
      state->handle,
      (INT_PCM *)state->decoder_buffer,
      state->decoder_buffer_size / sizeof(INT_PCM),
      0);
  if (err == AAC_DEC_NOT_ENOUGH_BITS) {
    MEMBRANE_WARN(env, "AAC: aacDecoder_DecodeFrame() - not enough bits supplied");
    return decode_frame_result_error_not_enough_bits(env);
  }
  if (err != AAC_DEC_OK) {
    MEMBRANE_WARN(env, "AAC: aacDecoder_DecodeFrame() failed: %x\n", err);
    return decode_frame_result_error_unknown(env);
  }

  CStreamInfo *stream_info = aacDecoder_GetStreamInfo(state->handle);

  UINT out_payload_size = stream_info->frameSize * stream_info->numChannels * sizeof(INT_PCM);
  UnifexPayload *out_payload = unifex_payload_alloc(env, in_payload->type, out_payload_size);
  memcpy(
      out_payload->data,
      state->decoder_buffer,
      out_payload_size);

  res = decode_frame_result_ok(
      env,
      out_payload,
      stream_info->frameSize,
      stream_info->sampleRate,
      stream_info->numChannels);
  unifex_payload_release_ptr(&out_payload);
  return res;
}

void handle_destroy_state(UnifexEnv *env, State *state) {
  if (state) {
    if (state->handle) {
      aacDecoder_Close(state->handle);
    }
    unifex_free(state->decoder_buffer);
  } else {
    MEMBRANE_WARN(env, "AAC: Decoder state already released");
  }
}
