#ifndef U8WINAPI_H
#define U8WINAPI_H

#include <windef.h>

#ifdef __cplusplus
extern "C" {
#endif

DWORD u8_FormatMessage(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPSTR lpBuffer, DWORD nSize, va_list *Arguments);
DWORD u8_GetModuleFileName(HMODULE hModule, LPSTR lpFilename, DWORD nSize);
HMODULE u8_LoadLibraryEx(LPCSTR lpFileName, HANDLE hFile, DWORD dwFlags);

#ifdef __cplusplus
}
#endif

#endif
