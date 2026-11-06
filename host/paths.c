#include <stdlib.h>
#include <string.h>
#include "moonbit.h"
#ifdef _WIN32
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#include <windows.h>
#include <limits.h>
#include <wchar.h>

static wchar_t *final_path(const unsigned char *path) {
  int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                 (const char *)path, -1, NULL, 0);
  if (count == 0) return NULL;
  wchar_t *wide = malloc((size_t)count * sizeof(wchar_t));
  if (!wide) return NULL;
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                           (const char *)path, -1, wide, count)) {
    free(wide);
    return NULL;
  }
  // Follow reparse points, and allow opening directories as well as files.
  HANDLE handle = CreateFileW(wide, 0,
                             FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                             NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  free(wide);
  if (handle == INVALID_HANDLE_VALUE) return NULL;
  DWORD capacity = GetFinalPathNameByHandleW(handle, NULL, 0,
                                            FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
  wchar_t *result = NULL;
  if (capacity > 0 && capacity <= INT_MAX) {
    result = malloc((size_t)capacity * sizeof(wchar_t));
    if (result) {
      DWORD length = GetFinalPathNameByHandleW(handle, result, capacity,
                                               FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
      if (length == 0 || length >= capacity) {
        free(result);
        result = NULL;
      }
    }
  }
  CloseHandle(handle);
  if (result) {
    // Normalize extended DOS and UNC prefixes without losing the UNC root.
    if (wcsncmp(result, L"\\\\?\\UNC\\", 8) == 0) {
      memmove(result + 2, result + 8, (wcslen(result + 8) + 1) * sizeof(wchar_t));
    } else if (wcsncmp(result, L"\\\\?\\", 4) == 0) {
      memmove(result, result + 4, (wcslen(result + 4) + 1) * sizeof(wchar_t));
    }
  }
  return result;
}

MOONBIT_FFI_EXPORT int moonfga_contained(const unsigned char *base, const unsigned char *path) {
  wchar_t *root = final_path(base);
  wchar_t *file = final_path(path);
  int ok = 0;
  if (root && file) {
    size_t n = wcslen(root);
    ok = n > 0 && wcslen(file) >= n &&
         CompareStringOrdinal(root, (int)n, file, (int)n, TRUE) == CSTR_EQUAL &&
         (root[n-1] == L'\\' || file[n] == L'\\');
  }
  free(root);
  free(file);
  return ok;
}
#else
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
#endif
