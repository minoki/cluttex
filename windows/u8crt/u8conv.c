#include "u8conv.h"

#include <assert.h>
#include <stdint.h>
#include <windows.h>

#ifdef _STATIC_ASSERT
_STATIC_ASSERT(sizeof(wchar_t) == 2);
#endif

size_t u8conv_u8towcs_len(const char *u8str)
{
    assert(u8str != NULL);
    size_t len = 0;
    while (*u8str) {
        unsigned char c = (unsigned char)*u8str++;
        if (c < 0x80) {
            // Single byte
            ++len;
        } else if (0xc0 <= c && c < 0xe0) {
            ++len;
            if (*u8str++ == '\0') {
                // second byte is NUL
                break;
            }
        } else if (0xe0 <= c && c < 0xf0) {
            ++len;
            if (*u8str++ == '\0') {
                // second byte is NUL
                break;
            }
            if (*u8str++ == '\0') {
                // third byte is NUL
                break;
            }
        } else if (0xf0 <= c && c < 0xf8) {
            len += 2;
            if (*u8str++ == '\0') {
                // second byte is NUL
                break;
            }
            if (*u8str++ == '\0') {
                // third byte is NUL
                break;
            }
            if (*u8str++ == '\0') {
                // fourth byte is NUL
                break;
            }
        } else {
            // Error
            break;
        }
    }
    return len;
}

// u8str is NUL-terminated
const wchar_t *u8conv_u8towcs(const char *u8str, u8conv_wcs_buffer_t *buf)
{
    assert(buf != NULL);
    buf->ptr = NULL;
    if (u8str == NULL) {
        return NULL;
    }
    int wlength = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8str, -1, NULL, 0);
    if (wlength <= 0) {
        // Conversion error
        return NULL;
    } else {
        // Note that wlength includes the terminating NUL
        if (wlength <= sizeof(buf->internalbuffer)) {
            buf->ptr = buf->internalbuffer;
        } else {
            buf->ptr = (wchar_t *)calloc(wlength, sizeof(wchar_t));
            if (buf->ptr == NULL) {
                // Memory error
                return NULL;
            }
        }
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8str, -1, buf->ptr, wlength);
        return buf->ptr;
    }
}
const wchar_t *u8conv_u8towcs_2(const char *u8str, u8conv_wcs_buffer_t *buf)
{
    assert(buf != NULL);
    buf->ptr = NULL;
    if (u8str == NULL) {
        return NULL;
    }
    const size_t internalbuffer_len = sizeof(buf->internalbuffer) / sizeof(buf->internalbuffer[0]);
    wchar_t *dstbuf = buf->internalbuffer;
    size_t dstlen = 0;
    while (*u8str) {
        if (dstlen >= internalbuffer_len - 2) {
            size_t restlen = u8conv_u8towcs_len(u8str);
            dstbuf = (wchar_t *)malloc((dstlen + restlen + 1) * sizeof(wchar_t));
            if (dstbuf == NULL) {
                // Memory error
                return NULL;
            }
            wmemcpy(dstbuf, buf->internalbuffer, dstlen);
            goto on_heap;
        }
        uint_fast32_t c = (unsigned char)*u8str++;
        if (c < 0x80) {
            // Single byte
            dstbuf[dstlen++] = c;
        } else if (0xc0 <= c && c < 0xe0) {
            // 2 bytes: [0x80, 0x800)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = ((c & 0x1f) << 6) | (c2 & 0x3f);
            if (value < 0x80) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xe0 <= c && c < 0xf0) {
            // 3 bytes: [0x800, 0x10000) minus [0xD800, 0xE000)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = ((c & 0x0f) << 12) | ((c2 & 0x3f) << 6) | (c3 & 0x3f);
            if (value < 0x800 || (0xd800 <= value && value < 0xe000)) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xf0 <= c && c < 0xf8) {
            // 4 bytes: [0x10000, 0x110000)
            uint_fast32_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c4 = (unsigned char)*u8str++;
            if (c4 < 0x80 || 0xc0 <= c4) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t value = ((c & 0x07) << 18) | ((c2 & 0x3f) << 12) | ((c3 & 0x3f) << 6) | (c4 & 0x3f);
            if (value < 0x10000 || 0x110000 <= value) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = 0xd800 | ((value - 0x10000) >> 10 & 0x03ff);
            dstbuf[dstlen++] = 0xdc00 | ((value - 0x10000) & 0x03ff);
        } else {
            goto illegal_sequence;
        }
    }
    dstbuf[dstlen] = L'\0';
    buf->ptr = dstbuf;
    return dstbuf;
 on_heap:
    while (*u8str) {
        uint_fast32_t c = (unsigned char)*u8str++;
        if (c < 0x80) {
            // Single byte
            dstbuf[dstlen++] = c;
        } else if (0xc0 <= c && c < 0xe0) {
            // 2 bytes: [0x80, 0x800)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = (c & 0x1f) << 6 | (c2 & 0x3f);
            if (value < 0x80) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xe0 <= c && c < 0xf0) {
            // 3 bytes: [0x800, 0x10000) minus [0xD800, 0xE000)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = (c & 0x0f) << 12 | (c2 & 0x3f) << 6 | (c3 & 0x3f);
            if (value < 0x800 || (0xd800 <= value && value < 0xe000)) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xf0 <= c && c < 0xf8) {
            // 4 bytes: [0x10000, 0x110000)
            uint_fast32_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c4 = (unsigned char)*u8str++;
            if (c4 < 0x80 || 0xc0 <= c4) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t value = (c & 0x07) << 18 | (c2 & 0x3f) << 12 | (c3 & 0x3f) << 6 | (c4 & 0x3f);
            if (value < 0x10000 || 0x110000 <= value) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = 0xd800 | ((value - 0x10000) >> 10 & 0x03ff);
            dstbuf[dstlen++] = 0xdc00 | ((value - 0x10000) & 0x03ff);
        } else {
            goto illegal_sequence;
        }
    }
    dstbuf[dstlen] = L'\0';
    buf->ptr = dstbuf;
    return dstbuf;
 illegal_sequence:
    if (dstbuf != buf->internalbuffer) {
        free(dstbuf);
    }
    return NULL;
}
const wchar_t *u8conv_u8towcs_3(const char *u8str, u8conv_wcs_buffer_t *buf)
{
    assert(buf != NULL);
    buf->ptr = NULL;
    if (u8str == NULL) {
        return NULL;
    }
    const size_t internalbuffer_len = sizeof(buf->internalbuffer) / sizeof(buf->internalbuffer[0]);
    wchar_t *dstbuf = buf->internalbuffer;
    size_t dstlen = 0;
    /*
    size_t u8len = u8conv_u8towcs_len(u8str);
    if (u8len >= internalbuffer_len) {
        dstbuf = (wchar_t *)malloc((u8len + 1) * sizeof(wchar_t));
        if (dstbuf == NULL) {
            // Memory error
            return NULL;
        }
    }
    */
    int reallocated = 0;
    while (*u8str) {
        if (!reallocated && dstlen >= internalbuffer_len - 2) {
            size_t restlen = u8conv_u8towcs_len(u8str);
            dstbuf = (wchar_t *)malloc((dstlen + restlen + 1) * sizeof(wchar_t));
            if (dstbuf == NULL) {
                // Memory error
                return NULL;
            }
            wmemcpy(dstbuf, buf->internalbuffer, dstlen);
            reallocated = 1;
        }
        uint_fast32_t c = (unsigned char)*u8str++;
        if (c < 0x80) {
            // Single byte
            dstbuf[dstlen++] = c;
        } else if (0xc0 <= c && c < 0xe0) {
            // 2 bytes: [0x80, 0x800)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = ((c & 0x1f) << 6) | (c2 & 0x3f);
            if (value < 0x80) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xe0 <= c && c < 0xf0) {
            // 3 bytes: [0x800, 0x10000) minus [0xD800, 0xE000)
            uint_fast16_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast16_t value = ((c & 0x0f) << 12) | ((c2 & 0x3f) << 6) | (c3 & 0x3f);
            if (value < 0x800 || (0xd800 <= value && value < 0xe000)) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = value;
        } else if (0xf0 <= c && c < 0xf8) {
            // 4 bytes: [0x10000, 0x110000)
            uint_fast32_t c2 = (unsigned char)*u8str++;
            if (c2 < 0x80 || 0xc0 <= c2) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c3 = (unsigned char)*u8str++;
            if (c3 < 0x80 || 0xc0 <= c3) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t c4 = (unsigned char)*u8str++;
            if (c4 < 0x80 || 0xc0 <= c4) { /* includes NUL case */
                goto illegal_sequence;
            }
            uint_fast32_t value = ((c & 0x07) << 18) | ((c2 & 0x3f) << 12) | ((c3 & 0x3f) << 6) | (c4 & 0x3f);
            if (value < 0x10000 || 0x110000 <= value) {
                goto illegal_sequence;
            }
            dstbuf[dstlen++] = 0xd800 | ((value - 0x10000) >> 10 & 0x03ff);
            dstbuf[dstlen++] = 0xdc00 | ((value - 0x10000) & 0x03ff);
        } else {
            goto illegal_sequence;
        }
    }
    dstbuf[dstlen] = L'\0';
    buf->ptr = dstbuf;
    return dstbuf;
 illegal_sequence:
    if (dstbuf != buf->internalbuffer) {
        free(dstbuf);
    }
    return NULL;
}
wchar_t *u8conv_allocatewcsbuf(size_t bufsize, u8conv_wcs_buffer_t *buf)
{
    assert(buf != NULL);
    if (bufsize > sizeof(buf->internalbuffer)/sizeof(buf->internalbuffer[0])) {
        wchar_t *ptr = calloc(bufsize, sizeof(wchar_t));
        buf->ptr = ptr;
        return ptr;
    } else {
        buf->ptr = buf->internalbuffer;
        return buf->ptr;
    }
}
void u8conv_freewcsbuf(u8conv_wcs_buffer_t *buf, size_t length)
{
    assert(buf != NULL);
    int olderrno;
    _get_errno(&olderrno);
    for (size_t i = 0; i < length; ++i) {
        if (buf[i].ptr != buf[i].internalbuffer) {
            free(buf[i].ptr);
        }
    }
    _set_errno(olderrno);
}

// No strict validation is done on the input
size_t u8conv_wcstou8_len(const wchar_t *s)
{
    assert(s != NULL);
    size_t len = 0;
    while (*s) {
        wchar_t c = *s++;
        if (c < 0x80) {
            len += 1;
        } else if (c < 0x800) {
            // ~ 11 bits
            len += 2;
        } else if (0xd800 <= c && c < 0xe000) {
            // a half of a surrogate pair
            len += 2;
        } else {
            // ~ 16 bits
            len += 3;
        }
    }
    return len;
}

char *u8conv_wcstou8_dup(const wchar_t *wstr)
{
    #ifdef WC_ERR_INVALID_CHARS
    const DWORD flags = WC_ERR_INVALID_CHARS;
    #else
    const DWORD flags = 0;
    #endif
    int u8length = WideCharToMultiByte(CP_UTF8, flags, wstr, -1, NULL, 0, NULL, NULL);
    if (u8length <= 0) {
        return NULL;
    } else {
        char *u8buffer = (char *)calloc(u8length, sizeof(char));
        if (u8buffer == NULL) {
            return NULL;
        } else {
            WideCharToMultiByte(CP_UTF8, flags, wstr, -1, u8buffer, u8length, NULL, NULL);
            return u8buffer;
        }
    }
}

char *u8conv_wcstou8_cpy(char *dst, size_t bufsize, const wchar_t *src)
{
    #ifdef WC_ERR_INVALID_CHARS
    const DWORD flags = WC_ERR_INVALID_CHARS;
    #else
    const DWORD flags = 0;
    #endif
    int result = WideCharToMultiByte(CP_UTF8, flags, src, -1, dst, bufsize, NULL, NULL);
    if (result <= 0) {
        return NULL;
    }
    return dst;
}

char *u8conv_wcstou8_cpy_l(char *dst, size_t bufsize, const wchar_t *src, size_t *actuallen)
{
    #ifdef WC_ERR_INVALID_CHARS
    const DWORD flags = WC_ERR_INVALID_CHARS;
    #else
    const DWORD flags = 0;
    #endif
    if (actuallen) {
        int u8length = WideCharToMultiByte(CP_UTF8, flags, src, -1, NULL, 0, NULL, NULL);
        if (u8length <= 0) {
            return NULL;
        }
        // u8length includes the terminating NUL
        *actuallen = u8length - 1;
    }
    if (WideCharToMultiByte(CP_UTF8, flags, src, -1, dst, bufsize, NULL, NULL) <= 0) {
        return NULL;
    } else {
        return dst;
    }
}

char *u8conv_wcstou8_cpy_l_2(char *dst, size_t bufsize, const wchar_t *src, size_t *actuallen_ptr)
{
    assert(dst != NULL);
    size_t dstlen = 0;
    while (*src && dstlen + 4 * 128 < bufsize) {
        int i = 128;
        while (--i >= 0) {
            wchar_t c = *src++;
            if (c < 0x80) {
                // 7 bits -> 1 byte
                if (c == 0) {
                    --src;
                    break;
                }
                dst[dstlen++] = c;
            } else if (c < 0x800) {
                // 11 bits -> 2 bytes
                dst[dstlen++] = 0xc0 | c >> 6;
                dst[dstlen++] = 0x80 | (c & 0x3f);
            } else if (0xd800 <= c && c < 0xe000) {
                wchar_t d = *src++;
                if (0xd800 <= c && c < 0xdc00 && 0xdc00 <= d && d < 0xe000) {
                    // 21 bits -> 4 bytes
                    uint_fast32_t value = (c & 0x3ff) << 10 | (d & 0x3ff);
                    dst[dstlen++] = 0xf0 | value >> 18;
                    dst[dstlen++] = 0x80 | ((value >> 12) & 0x3f);
                    dst[dstlen++] = 0x80 | ((value >> 6) & 0x3f);
                    dst[dstlen++] = 0x80 | (value & 0x3f);
                } else {
                    goto illegal_sequence;
                }
            } else {
                // 16 bits -> 3 bytes
                dst[dstlen++] = 0xe0 | c >> 12;
                dst[dstlen++] = 0x80 | ((c >> 6) & 0x3f);
                dst[dstlen++] = 0x80 | (c & 0x3f);
            }
        }
    }
    while (*src) {
        wchar_t c = *src++;
        if (c < 0x80) {
            // 7 bits -> 1 byte
            if (dstlen + 1 >= bufsize) {
                goto exhausted;
            }
            dst[dstlen++] = c;
        } else if (c < 0x800) {
            // 11 bits -> 2 bytes
            if (dstlen + 2 >= bufsize) {
                goto exhausted;
            }
            dst[dstlen++] = 0xc0 | c >> 6;
            dst[dstlen++] = 0x80 | (c & 0x3f);
        } else if (0xd800 <= c && c < 0xe000) {
            wchar_t d = *src++;
            if (0xd800 <= c && c < 0xdc00 && 0xdc00 <= d && d < 0xe000) {
                // 21 bits -> 4 bytes
                if (dstlen + 4 >= bufsize) {
                    goto exhausted;
                }
                uint_fast32_t value = (c & 0x3ff) << 10 | (d & 0x3ff);
                dst[dstlen++] = 0xf0 | value >> 18;
                dst[dstlen++] = 0x80 | ((value >> 12) & 0x3f);
                dst[dstlen++] = 0x80 | ((value >> 6) & 0x3f);
                dst[dstlen++] = 0x80 | (value & 0x3f);
            } else {
                goto illegal_sequence;
            }
        } else {
            // 16 bits -> 3 bytes
            if (dstlen + 3 >= bufsize) {
                goto exhausted;
            }
            dst[dstlen++] = 0xe0 | c >> 12;
            dst[dstlen++] = 0x80 | ((c >> 6) & 0x3f);
            dst[dstlen++] = 0x80 | (c & 0x3f);
        }
    }
    if (actuallen_ptr != NULL) {
        *actuallen_ptr = dstlen;
    }
    assert(dstlen < bufsize);
    dst[dstlen] = '\0';
    return dst;
 exhausted:
    assert(dstlen < bufsize);
    dst[dstlen] = '\0';
    if (actuallen_ptr != NULL) {
        // The caller wants the actual length anyway
        *actuallen_ptr = dstlen + u8conv_wcstou8_len(src - 1);
    }
    return dst;
 illegal_sequence:
    assert(dstlen < bufsize);
    dst[dstlen] = '\0';
    if (actuallen_ptr != NULL) {
        *actuallen_ptr = dstlen;
    }
    return NULL;
}
