#include <stdlib.h>
#include <string.h>
#include "moonbit.h"
MOONBIT_FFI_EXPORT int moonfga_contained(const unsigned char *base, const unsigned char *path) {
  char *root = realpath((const char *)base, NULL);
  char *file = realpath((const char *)path, NULL);
  int ok = 0;
  if (root && file) {
    size_t n = strlen(root);
    ok = strncmp(root, file, n) == 0 && (root[n-1] == '/' || file[n] == '/');
  }
  free(root);
  free(file);
  return ok;
}
