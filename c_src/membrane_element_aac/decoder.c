#include "decoder.h"

UNIFEX_TERM create(UnifexEnv *env)
{
  State *state = unifex_alloc_state(env);

  UNIFEX_TERM res = create_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM decode_frame(UnifexEnv *env, UnifexPayload *in_payload, State *state)
{
  UNIFEX_TERM res = decode_frame_result_ok(env);
  return res;
}

void handle_destroy_state(UnifexEnv *env, State *state)
{
  UNIFEX_UNUSED(env);
}
