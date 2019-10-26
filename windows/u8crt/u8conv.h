#ifndef U8CRT_U8CONV_H
#define U8CRT_U8CONV_H

#include <stddef.h>
#include <wchar.h>

#if defined(_MSC_VER) /*|| (defined(__has_include) && __has_include(<sal.h>))*/
#include <sal.h>
#else
#define _In_
#define _Out_
#define _Inout_
#define _In_z_
#define _Inout_z_
#define _In_opt_
#define _Out_opt_
#define _Inout_opt_
#define _In_opt_z_
#define _Inout_opt_z_
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __GNUC__
#define U8CRT_U8CONV_ATTR_NONNULL(n) __attribute__((__nonnull__(n)))
#else
#define U8CRT_U8CONV_ATTR_NONNULL(n)
#endif

size_t u8conv_u8towcs_len(_In_z_ const char *u8str) U8CRT_U8CONV_ATTR_NONNULL(1);
typedef struct u8conv_wcs_buffer {
    wchar_t *ptr;
    wchar_t internalbuffer[1024];
} u8conv_wcs_buffer_t;
const wchar_t *u8conv_u8towcs(_In_opt_z_ const char *u8str, _Out_ u8conv_wcs_buffer_t *buf) U8CRT_U8CONV_ATTR_NONNULL(2);
wchar_t *u8conv_allocatewcsbuf(size_t bufsize, _Out_ u8conv_wcs_buffer_t *buf) U8CRT_U8CONV_ATTR_NONNULL(2);
void u8conv_freewcsbuf(u8conv_wcs_buffer_t *buf, size_t length);

size_t u8conv_wcstou8_len(_In_z_ const wchar_t *s) U8CRT_U8CONV_ATTR_NONNULL(1); /* This function does not check for invalid coding (i.e. orphaned surrogate pair) */
char *u8conv_wcstou8_dup(_In_opt_z_ const wchar_t *str);
char *u8conv_wcstou8_cpy(char *dst, size_t bufsize, const wchar_t *src) U8CRT_U8CONV_ATTR_NONNULL(1); /* Returns dst on success, NULL on failure */
char *u8conv_wcstou8_cpy_l(char *dst, size_t bufsize, const wchar_t *src, size_t *actuallen) U8CRT_U8CONV_ATTR_NONNULL(1); /* Returns dst on success, NULL on failure */

#define CONVERT_INPUT_TO_WCS_1(ustr1, wstr1)                            \
    u8conv_wcs_buffer_t _u8conv_wcs_buffers[1];                         \
    const wchar_t *wstr1 = u8conv_u8towcs((ustr1), &_u8conv_wcs_buffers[0])

#define CONVERT_INPUT_TO_WCS_2(ustr1, wstr1, ustr2, wstr2)              \
    u8conv_wcs_buffer_t _u8conv_wcs_buffers[2];                         \
    const wchar_t *wstr1 = u8conv_u8towcs((ustr1), &_u8conv_wcs_buffers[0]), \
                  *wstr2 = u8conv_u8towcs((ustr2), &_u8conv_wcs_buffers[1])

#define U8CONV_CLEANUP_BUFFERS() \
    u8conv_freewcsbuf(_u8conv_wcs_buffers, sizeof(_u8conv_wcs_buffers) / sizeof(_u8conv_wcs_buffers[0]))

#define RETURN_T(expr, type)                    \
    do {                                        \
        type _u8conv_result = (expr);           \
        U8CONV_CLEANUP_BUFFERS();               \
        return _u8conv_result;                  \
    } while (0)

#ifdef __cplusplus
}
#endif

#endif
