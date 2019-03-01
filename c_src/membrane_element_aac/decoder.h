#pragma once

#include <fdk-aac/aacdecoder_lib.h>
#include "stdint.h"

typedef struct _DecoderState UnifexNifState;
typedef UnifexNifState State;

struct _DecoderState
{
  HANDLE_AACDECODER handle;
  uint8_t *decoder_buffer;
  int decoder_buffer_size;
};

#include "_generated/decoder.h"
