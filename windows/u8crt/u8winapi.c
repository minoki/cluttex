#include "u8winapi.h"
#include "u8conv.h"
#include <windows.h>
#include <assert.h>

static DWORD u8_FormatMessage_allocate_buffer(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPSTR* lpBuffer, DWORD nSize, va_list *Arguments)
{
    assert(dwFlags & FORMAT_MESSAGE_ALLOCATE_BUFFER);
    if (dwFlags & FORMAT_MESSAGE_FROM_STRING) {
        // unsupported configuration
        SetLastError(ERROR_INVALID_PARAMETER);
        return 0;
    } else {
        if (dwFlags & FORMAT_MESSAGE_IGNORE_INSERTS) {
            // Arguments is ignored
            LPWSTR lpWideBuffer = NULL;
            DWORD result = FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId, (LPWSTR)&lpWideBuffer, 0, NULL);
            if (result == 0) {
                // error
                return 0;
            }
            size_t u8len = u8conv_wcstou8_len(lpWideBuffer);
            char *u8buffer = LocalAlloc(LMEM_FIXED, nSize > u8len ? nSize : u8len+1);
            u8conv_wcstou8_cpy(u8buffer, u8len+1, lpWideBuffer);
            LocalFree(lpWideBuffer);
            *lpBuffer = u8buffer;
            return u8len;
        } else if (dwFlags & FORMAT_MESSAGE_ARGUMENT_ARRAY) {
            // Arguments is DWORD_PTR*
            DWORD_PTR* ArgumentsDW = (DWORD_PTR*)Arguments;
            (void)ArgumentsDW;
            SetLastError(ERROR_INVALID_PARAMETER);
            return 0;
        } else {
            // Arguments is va_list*
            SetLastError(ERROR_INVALID_PARAMETER);
            return 0;
        }
    }
}

DWORD u8_FormatMessage(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPSTR lpBuffer, DWORD nSize, va_list *Arguments)
{
    if (dwFlags & FORMAT_MESSAGE_ALLOCATE_BUFFER) {
        return u8_FormatMessage_allocate_buffer(dwFlags, lpSource, dwMessageId, dwLanguageId, (LPSTR*)lpBuffer, nSize, Arguments);
    } else {
        if (dwFlags & FORMAT_MESSAGE_FROM_STRING) {
            // unsupported configuration
            SetLastError(ERROR_INVALID_PARAMETER);
            return 0;
        } else {
            if (dwFlags & FORMAT_MESSAGE_IGNORE_INSERTS) {
                // Arguments is ignored
                u8conv_wcs_buffer_t wideBuffer;
                LPWSTR lpWideBuffer = u8conv_allocatewcsbuf(nSize, &wideBuffer);
                DWORD result = FormatMessageW(dwFlags, lpSource, dwMessageId, dwLanguageId, lpWideBuffer, nSize, NULL);
                if (result == 0) {
                    // error
                    u8conv_freewcsbuf(&wideBuffer, 1);
                    return 0;
                }
                size_t actuallen = 0;
                u8conv_wcstou8_cpy_l(lpBuffer, nSize, lpWideBuffer, &actuallen);
                u8conv_freewcsbuf(&wideBuffer, 1);
                return actuallen;
            } else if (dwFlags & FORMAT_MESSAGE_ARGUMENT_ARRAY) {
                // Arguments is DWORD_PTR*
                DWORD_PTR* ArgumentsDW = (DWORD_PTR*)Arguments;
                (void)ArgumentsDW;
                SetLastError(ERROR_INVALID_PARAMETER);
                return 0;
            } else {
                // Arguments is va_list*
                SetLastError(ERROR_INVALID_PARAMETER);
                return 0;
            }
        }
    }
}

DWORD u8_GetModuleFileName(HMODULE hModule, LPSTR lpFilename, DWORD nSize)
{
    u8conv_wcs_buffer_t wideBuffer;
    WCHAR *buffer = u8conv_allocatewcsbuf(nSize, &wideBuffer);
    DWORD result = GetModuleFileNameW(hModule, buffer, nSize);
    if (result == 0) {
        // error
        u8conv_freewcsbuf(&wideBuffer, 1);
        return 0;
    }
    size_t actuallen = 0;
    u8conv_wcstou8_cpy_l(lpFilename, nSize, buffer, &actuallen);
    u8conv_freewcsbuf(&wideBuffer, 1);
    if (actuallen+1 > nSize) {
        SetLastError(ERROR_INSUFFICIENT_BUFFER);
        return nSize;
    }
    return actuallen;
}

HMODULE u8_LoadLibraryEx(LPCSTR lpFileName, HANDLE hFile, DWORD dwFlags)
{
    CONVERT_INPUT_TO_WCS_1(lpFileName, wFileName);
    RETURN_T(LoadLibraryExW(wFileName, hFile, dwFlags), HMODULE);
}
