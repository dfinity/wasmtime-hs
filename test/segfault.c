#include <assert.h>
#include <wasm.h>
#include <wasmtime.h>
#include <stdio.h>

int main() {
  wasm_engine_t *engine = wasm_engine_new();
  assert(engine != NULL);
  wasmtime_store_t *store = wasmtime_store_new(engine, NULL, NULL);
  assert(store != NULL);
  wasmtime_context_t *context = wasmtime_store_context(store);

  uint8_t wasm[8] = {0, 97, 115, 109, 1, 0, 0, 0};

  wasmtime_module_t *module = NULL;
  wasmtime_error_t *error = wasmtime_module_new(engine, wasm, 8, &module);
  assert(error == NULL);
  assert(module != NULL);

  wasmtime_instance_t instance;
  wasm_trap_t *trap = NULL;
  error = wasmtime_instance_new(context, module, NULL, 0, &instance, &trap);
  assert(error == NULL);
  assert(trap == NULL);

  // fprintf(stderr, "trap = %p", (void*)trap);
  // wasmtime_trap_code_t code;
  // wasmtime_trap_code(trap, &code);
}
