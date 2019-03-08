#pragma once

#include <fdk-aac/aacenc_lib.h>
#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.Element.AAC.EncoderNative"
#include <membrane/log.h>

typedef struct _EncoderState {
  HANDLE_AACENCODER handle;
  unsigned char *aac_buffer;
  int channels;
} UnifexNifState;

typedef UnifexNifState State;

#include "_generated/encoder.h"
