#include "encoder.h"

static const int SAMPLE_SIZE = 2;
static const int MAX_AAC_BUFFER_SIZE = 8192; // TODO: Validate

static const int PROFILE_AAC_HE = 5;
static const int PROFILE_AAC_HE_v2 = 29;
static const int PROFILE_MPEG2_AAC_HE = 132;

/**
 * AAC Encoder implementation.
 * Heavily inspired by
 * https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/libfdk-aacenc.c
 */

/**
 * Returns a string description for the error code.
 */
char *get_error_message(AACENC_ERROR err) {
  switch (err) {
  case AACENC_OK:
    return "No error";
  case AACENC_INVALID_HANDLE:
    return "Invalid handle";
  case AACENC_MEMORY_ERROR:
    return "Memory allocation error";
  case AACENC_UNSUPPORTED_PARAMETER:
    return "Unsupported parameter";
  case AACENC_INVALID_CONFIG:
    return "Invalid config";
  case AACENC_INIT_ERROR:
    return "Initialization error";
  case AACENC_INIT_AAC_ERROR:
    return "AAC library initialization error";
  case AACENC_INIT_SBR_ERROR:
    return "SBR library initialization error";
  case AACENC_INIT_TP_ERROR:
    return "Transport library initialization error";
  case AACENC_INIT_META_ERROR:
    return "Metadata library initialization error";
  case AACENC_ENCODE_ERROR:
    return "Encoding error";
  case AACENC_ENCODE_EOF:
    return "End of file";
  default:
    return "Unknown error";
  }
}

/**
 * Initializes AAC Encoder and returns State resource.
 *
 * Expects:
 * - channels - Number of channels. 
 * - sample_rate - Sample rate.
 * - aot - Audio Object Type.
 * - bitrate_mode - 0 for CBR, 1-5 for VBR mode. See:
 * http://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC#Bitrate_Modes
 *
 * On success, returns {:ok, encoder_state}
 * In case of error, returns:
 * - {:error, reason}
 */
UNIFEX_TERM create(UnifexEnv *env, int channels, int sample_rate, int aot,
                   int bitrate_mode, int bitrate) {
  State *state = unifex_alloc_state(env);
  state->channels = channels;

  AACENC_ERROR err;
  CHANNEL_MODE channel_mode;
  // See:
  // https://wiki.multimedia.cx/index.php/Understanding_AAC#Frames_And_Syntax_Elements
  int sce = 0, cpe = 0;

  // Initialize AAC Encoder handle
  err = aacEncOpen(&state->handle, 0, channels);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Could not initialize encoder: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  // Set Audio Object Type
  err = aacEncoder_SetParam(state->handle, AACENC_AOT, aot);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to set the AOT: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  // Set sample rate
  err = aacEncoder_SetParam(state->handle, AACENC_SAMPLERATE, sample_rate);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to set sample rate: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  // Set transport type
  err = aacEncoder_SetParam(state->handle, AACENC_TRANSMUX, TT_MP4_ADTS);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to set transport type: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  // Set channels configuration
  switch (channels) {
  case 1: channel_mode = MODE_1;         sce = 1; cpe = 0; break;
  case 2: channel_mode = MODE_2;         sce = 0; cpe = 1; break;
  case 3: channel_mode = MODE_1_2;       sce = 1; cpe = 1; break;
  case 4: channel_mode = MODE_1_2_1;     sce = 2; cpe = 1; break;
  case 5: channel_mode = MODE_1_2_2;     sce = 1; cpe = 2; break;
  case 6: channel_mode = MODE_1_2_2_1;   sce = 2; cpe = 2; break;
  case 7: channel_mode = MODE_6_1;       sce = 3; cpe = 2; break;
  case 8: channel_mode = MODE_1_2_2_2_1; sce = 2; cpe = 3; break;
  default:
    MEMBRANE_WARN(env, "AAC: Unsupported number of channels: %d", channels);
    return create_result_error(env, get_error_message(err));
  }
  err = aacEncoder_SetParam(state->handle, AACENC_CHANNELMODE, channel_mode);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to set channel mode %d: %x\n", channel_mode,
                  err);
    return create_result_error(env, get_error_message(err));
  }

  err = aacEncoder_SetParam(state->handle, AACENC_CHANNELORDER, 1);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to set channel order: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  // Set bitrate
  if (bitrate_mode) {
    // VBR
    if (bitrate_mode < 1 || bitrate_mode > 5) {
      MEMBRANE_WARN(
          env, "AAC: Unable to set VBR mode: %d. VBR quality should be 1-5\n",
          bitrate_mode);
      return create_result_error(env, "invalid_vbr");
    }
    err = aacEncoder_SetParam(state->handle, AACENC_BITRATEMODE, bitrate_mode);
    if (err != AACENC_OK) {
      MEMBRANE_WARN(env, "AAC: Unable to set VBR %d: %x\n", bitrate_mode, err);
      return create_result_error(env, get_error_message(err));
    }
  } else {
    // CBR
    // If bitrate is not specified by the user, this will estimate the bitrate,
    // following the "rule of thumb" described here:
    // https://trac.ffmpeg.org/wiki/Encode/AAC#fdk_cbr This is based on:
    // https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/libfdk-aacenc.c#L245
    if (!bitrate) {
      bitrate = (96 * sce + 128 * cpe) * sample_rate / 44;
    }
    if (aot == PROFILE_AAC_HE || aot == PROFILE_AAC_HE_v2 ||
        aot == PROFILE_MPEG2_AAC_HE) {
      bitrate /= 2;
    }
    err = aacEncoder_SetParam(state->handle, AACENC_BITRATE, bitrate);
    if (err != AACENC_OK) {
      MEMBRANE_WARN(env, "AAC: Unable to set bitrate: %x\n", err);
      return create_result_error(env, get_error_message(err));
    }
  }

  state->aac_buffer = unifex_alloc(MAX_AAC_BUFFER_SIZE);
  if (!state->aac_buffer) {
    MEMBRANE_WARN(env, "AAC: Unable to initialize AAC buffer\n", err);
    return create_result_error(env, "no_memory");
  }

  // Initialize the encoder with preset parameters
  err = aacEncEncode(state->handle, NULL, NULL, NULL, NULL);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Unable to initialize the encoder: %x\n", err);
    return create_result_error(env, get_error_message(err));
  }

  UNIFEX_TERM res = create_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

/**
 * Encodes one input frame.
 *
 * Expects:
 * - Buffer to encoder
 * - Native resource
 * as arguments
 *
 * Returns on of:
 * - {:ok, {encoded_frame}} - Encoded AAC frame
 * - {:error, :no_data} - When supplied input buffer does not contain enough
 * data to encode a single frame
 * - {:error, reason} - When native encoding failed
 */
UNIFEX_TERM encode_frame(UnifexEnv *env, UnifexPayload *in_payload,
                         State *state) {
  UNIFEX_TERM res;
  AACENC_ERROR err;

  AACENC_BufDesc in_buf = {0}, out_buf = {0};
  AACENC_InArgs in_args = {0};
  AACENC_OutArgs out_args = {0};
  int in_buffer_identifier = IN_AUDIO_DATA;
  int in_buffer_size, in_buffer_element_size;
  int out_buffer_identifier = OUT_BITSTREAM_DATA;
  int out_buffer_size, out_buffer_element_size;
  void *in_ptr, *out_ptr;
  uint8_t dummy_buf[1];

  /* Handle :end_of_stream and flush */
  if (!in_payload->size) {
    in_ptr = dummy_buf;
    in_buffer_size = 0;

    in_args.numInSamples = -1;
  } else {
    int number_of_samples = in_payload->size / (state->channels * SAMPLE_SIZE);

    in_ptr = in_payload->data;
    in_buffer_size = SAMPLE_SIZE * state->channels * number_of_samples;

    in_args.numInSamples = state->channels * number_of_samples;
  }

  in_buffer_element_size = SAMPLE_SIZE;
  in_buf.numBufs = 1;
  in_buf.bufs = &in_ptr;
  in_buf.bufferIdentifiers = &in_buffer_identifier;
  in_buf.bufSizes = &in_buffer_size;
  in_buf.bufElSizes = &in_buffer_element_size;

  out_ptr = state->aac_buffer;
  out_buffer_size = MAX_AAC_BUFFER_SIZE;
  out_buffer_element_size = 1;
  out_buf.numBufs = 1;
  out_buf.bufs = &out_ptr;
  out_buf.bufferIdentifiers = &out_buffer_identifier;
  out_buf.bufSizes = &out_buffer_size;
  out_buf.bufElSizes = &out_buffer_element_size;

  err = aacEncEncode(state->handle, &in_buf, &out_buf, &in_args, &out_args);
  if (err != AACENC_OK) {
    MEMBRANE_WARN(env, "AAC: Encode error: %x\n", err);
    return encode_frame_result_error(env, get_error_message(err));
  }

  if (!out_args.numOutBytes) {
    return encode_frame_result_error_no_data(env);
  }

  UnifexPayload out_payload;
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, out_args.numOutBytes,
                       &out_payload);
  memcpy(out_payload.data, state->aac_buffer, out_args.numOutBytes);
  res = encode_frame_result_ok(env, &out_payload);
  unifex_payload_release(&out_payload);
  return res;
}

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);
  if (state->handle) {
    aacEncClose(&state->handle);
  }
  unifex_free(state->aac_buffer);
}
