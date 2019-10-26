#ifndef U8CRT_H
#define U8CRT_H

#include <stddef.h> /* size_t */
#include <stdio.h> /* FILE */
#include <stdint.h> /* intptr_t */
#include <time.h> /* struct tm */
#include <io.h> /* struct _finddata_t */
#include <sys/types.h>
#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

// <stdio.h>
int u8_puts(const char *str); /* puts, _putws */
#if 0
size_t u8_fwrite(const void *buffer, size_t size, size_t count, FILE *stream); /* fwrite */
int u8_fprintf(FILE *stream, const char *format, ...); /* fprintf, fwprintf */
int u8_vfprintf(FILE *stream, const char *format, va_list argptr); /* vfprintf, vfwprintf */
int u8_getc(FILE *stream); /* getc, getwc */
int u8_ungetc(int c, FILE *stream); /* ungetc, ungetwc */
size_t u8_fread(void *buffer, size_t size, size_t count, FILE *stream); /* fread */
char *u8_fgets(char *str, int n, FILE *stream); /* fgets, fgetws */
int u8_fputs(const char *str, FILE *stream); /* fputs, fputws */
#endif
FILE *u8_fopen(const char *filename, const char *mode); /* fopen, _wfopen */
FILE *u8_freopen(const char *path, const char *mode, FILE *stream); /* freopen, _wfreopen */
FILE *u8_popen(const char *command, const char *mode); /* _popen, _wpopen */
int u8_remove(const char *path); /* remove, _wremove */
int u8_rename(const char *oldname, const char *newname); /* rename, _wrename */
char *u8_tmpnam(char *str); /* tmpnam, _wtmpnam */

// <stdlib.h>
char *u8_getenv(const char *varname); /* getenv, _wgetenv */
int u8_putenv(const char *envstring); /* _putenv, _wputenv */
int u8_system(const char *command); /* system, _wsystem */

// <string.h>
char *u8_strerror(int errnum); /* strerror, _wcserror */

// <time.h>
size_t u8_strftime(char *strDest, size_t maxsize, const char *format, const struct tm *timeptr); /* strftime, wcsftime */

// <io.h>
char *u8_mktemp(char *template); /* _mktemp, _wmktemp */
intptr_t u8_findfirst(const char *filespec, struct _finddata_t *fileinfo); /* 32-bit file size */
int u8_findnext(intptr_t handle, struct _finddata_t *fileinfo);
intptr_t u8_findfirst64(const char *filespec, struct __finddata64_t *fileinfo); /* 64-bit time, 64-bit file size */
int u8_findnext64(intptr_t handle, struct __finddata64_t *fileinfo);
intptr_t u8_findfirsti64(const char *filespec, struct _finddatai64_t *fileinfo); /* 64-bit file size */
int u8_findnexti64(intptr_t handle, struct _finddatai64_t *fileinfo);
intptr_t u8_findfirst64i32(const char *filespec, struct _finddata64i32_t *fileinfo); /* 64-bit time, 32-bit file size */
int u8_findnext64i32(intptr_t handle, struct _finddata64i32_t *fileinfo);
#ifndef _WIN64
intptr_t u8_findfirst32(const char *filespec, struct _finddata32_t *fileinfo); /* 32-bit time, 32-bit file size */
int u8_findnext32(intptr_t handle, struct _finddata32_t *fileinfo);
intptr_t u8_findfirst32i64(const char *filespec, struct _finddata32i64_t *fileinfo); /* 32-bit time, 64-bit file size */
int u8_findnext32i64(intptr_t handle, struct _finddata32i64_t *fileinfo);
#endif

// <direct.h>
int u8_chdir(const char *dirname); /* _chdir, _wchdir */
char *u8_getcwd(char *buffer, int maxlen); /* _getcwd, _wgetcwd */
int u8_rmdir(const char *dirname); /* _rmdir, _wrmdir */
int u8_mkdir(const char *dirname); /* _mkdir, _wmkdir */

// <sys/stat.h>
int u8_stat64(const char *path, struct _stat64 *buffer); /* 64-bit time, 64-bit file size */
int u8_stat64i32(const char *path, struct _stat64i32 *buffer); /* 64-bit time, 32-bit file size */
#ifndef _WIN64
int u8_stat32(const char *path, struct _stat32 *buffer); /* 32-bit time, 32-bit file size */
int u8_stat32i64(const char *path, struct _stat32i64 *buffer); /* 32-bit time, 64-bit file size */
#endif

#ifdef __cplusplus
}
#endif

#endif
