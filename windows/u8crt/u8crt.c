#include "u8crt.h"
#include "u8conv.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <io.h>
#include <direct.h>
#include <wchar.h>
#include <errno.h>
#include <assert.h>

// <stdio.h>
int u8_puts(const char *str)
{
    CONVERT_INPUT_TO_WCS_1(str, wstr);
    int result = _putws(wstr);
    if (result == WEOF) {
        result = EOF;
    }
    U8CONV_CLEANUP_BUFFERS();
    return result;
}

int u8_fputs(const char *str, FILE *stream)
{
    CONVERT_INPUT_TO_WCS_1(str, wstr);
    int result = fputws(wstr, stream);
    if (result == WEOF) {
        result = EOF;
    }
    U8CONV_CLEANUP_BUFFERS();
    return result;
}

FILE *u8_fopen(const char *filename, const char *mode)
{
    CONVERT_INPUT_TO_WCS_2(filename, wfilename, mode, wmode);
    RETURN_T(_wfopen(wfilename, wmode), FILE *);
}

FILE *u8_freopen(const char *path, const char *mode, FILE *stream)
{
    CONVERT_INPUT_TO_WCS_2(path, wpath, mode, wmode);
    RETURN_T(_wfreopen(wpath, wmode, stream), FILE *);
}

FILE *u8_popen(const char *command, const char *mode)
{
    CONVERT_INPUT_TO_WCS_2(command, wcommand, mode, wmode);
    // _wpopen(wcommand, wmode) sets EINVAL if wcommand or wmode is a null pointer.
    RETURN_T(_wpopen(wcommand, wmode), FILE *);
}

int u8_remove(const char *path)
{
    CONVERT_INPUT_TO_WCS_1(path, wpath);
    RETURN_T(_wremove(wpath), int);
}

int u8_rename(const char *oldname, const char *newname)
{
    CONVERT_INPUT_TO_WCS_2(oldname, woldname, newname, wnewname);
    RETURN_T(_wrename(woldname, wnewname), int);
}

char *u8_tmpnam(char *str)
{
    wchar_t wbuffer[L_tmpnam];
    if (_wtmpnam(wbuffer) == NULL) {
        return NULL;
    }
    size_t bufsize;
    if (str == NULL) {
        static char u8buffer[L_tmpnam * 3];
        str = u8buffer;
        bufsize = sizeof(u8buffer);
    } else {
        bufsize = L_tmpnam;
    }
    // str is assumed to point to an array of at least L_tmpnam chars.
    return u8conv_wcstou8_cpy(str, bufsize, wbuffer);
}

// <stdlib.h>
static char **u8_environ_cache; /* = {"NAME1=VALUE1", "NAME2=VALUE2", ..., NULL}; */
static char **lookup_environ_cache(const char *varname, size_t varname_len)
{
    if (u8_environ_cache == NULL) {
        u8_environ_cache = calloc(1, sizeof(char *));
        return u8_environ_cache;
    } else {
        char **iter = u8_environ_cache;
        for (; *iter != NULL; ++iter) {
            if (strncmp(*iter, varname, varname_len) == 0 && (*iter)[varname_len] == '=') {
                /* found */
                return iter;
            }
        }
        return iter;
    }
}
char *u8_getenv(const char *varname)
{
    wchar_t *value = NULL;
    {
        CONVERT_INPUT_TO_WCS_1(varname, wvarname);
        value = _wgetenv(wvarname);
        U8CONV_CLEANUP_BUFFERS();
    }
    if (value == NULL) {
        return NULL;
    } else {
        size_t varname_len = strlen(varname);
        size_t u8value_len = u8conv_wcstou8_len(value); // TODO: error handling
        char **entry = lookup_environ_cache(varname, varname_len);
        if (*entry == NULL) {
            /* not found; add a new entry */
            ptrdiff_t existing_entries = entry - u8_environ_cache;
            u8_environ_cache = (char **)realloc(u8_environ_cache, (existing_entries + 2) * sizeof(char **));
            if (u8_environ_cache == NULL) {
                /* Memory error */
                return NULL;
            }
            u8_environ_cache[existing_entries + 1] = NULL;
            entry = &u8_environ_cache[existing_entries];
            *entry = (char *)malloc((varname_len + u8value_len + 2) * sizeof(char));
            if (*entry == NULL) {
                /* Memory error */
                return NULL;
            }
            strcpy(*entry, varname);
            (*entry)[varname_len] = '=';
            (*entry)[varname_len + 1] = '\0';
        } else {
            *entry = (char *)realloc(*entry, (varname_len + u8value_len + 2) * sizeof(char));
            if (*entry == NULL) {
                /* Memory error */
                return NULL;
            }
        }
        u8conv_wcstou8_cpy(*entry + varname_len + 1, u8value_len + 1, value);
        return *entry + varname_len + 1;
    }
}

int u8_putenv(const char *envstring) /* _putenv, _wputenv */
{
    CONVERT_INPUT_TO_WCS_1(envstring, wenvstring);
    RETURN_T(_wputenv(wenvstring), int);
}

int u8_system(const char *command)
{
    if (command == NULL) {
        return _wsystem(NULL);
    } else {
        CONVERT_INPUT_TO_WCS_1(command, wcommand);
        if (wcommand == NULL) {
            errno = EINVAL;
            return -1;
        }
        RETURN_T(_wsystem(wcommand), int);
    }
}

// <string.h>
char *u8_strerror(int errnum)
{
    // NOT IMPLEMENTED YET
    return strerror(errnum);
}

// <time.h>
size_t u8_strftime(char *strDest, size_t maxsize, const char *format, const struct tm *timeptr)
{
    // NOT IMPLEMENTED YET
    return strftime(strDest, maxsize, format, timeptr);
}

// <io.h>
char *u8_mktemp(char *template)
{
    // NOT IMPLEMENTED YET
    return _mktemp(template);
}
#define DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst, u8_findnext, _finddata_t, _wfinddata_t, _wfindfirst, _wfindnext) \
    intptr_t u8_findfirst(const char *filespec, struct _finddata_t *fileinfo) \
    {                                                                   \
        if (filespec == NULL || fileinfo == NULL) {                     \
            _set_errno(EINVAL);                                         \
            return -1;                                                  \
        }                                                               \
        struct _wfinddata_t wfileinfo;                                  \
        intptr_t handle;                                                \
        {                                                               \
            CONVERT_INPUT_TO_WCS_1(filespec, wfilespec);                \
            handle = _wfindfirst(wfilespec, &wfileinfo);                \
            U8CONV_CLEANUP_BUFFERS();                                   \
        }                                                               \
        if (handle != -1) {                                             \
            fileinfo->attrib = wfileinfo.attrib;                        \
            fileinfo->time_create = wfileinfo.time_create;              \
            fileinfo->time_access = wfileinfo.time_access;              \
            fileinfo->time_write = wfileinfo.time_write;                \
            fileinfo->size = wfileinfo.size;                            \
            u8conv_wcstou8_cpy(fileinfo->name, sizeof(fileinfo->name), wfileinfo.name); \
        }                                                               \
        return handle;                                                  \
    }                                                                   \
    int u8_findnext(intptr_t handle, struct _finddata_t *fileinfo)      \
    {                                                                   \
        if (fileinfo == NULL) {                                         \
            _set_errno(EINVAL);                                         \
            return -1;                                                  \
        }                                                               \
        struct _wfinddata_t wfileinfo;                                  \
        int result = _wfindnext(handle, &wfileinfo);                    \
        if (result == 0) {                                              \
            fileinfo->attrib = wfileinfo.attrib;                        \
            fileinfo->time_create = wfileinfo.time_create;              \
            fileinfo->time_access = wfileinfo.time_access;              \
            fileinfo->time_write = wfileinfo.time_write;                \
            fileinfo->size = wfileinfo.size;                            \
            u8conv_wcstou8_cpy(fileinfo->name, sizeof(fileinfo->name), wfileinfo.name); \
        }                                                               \
        return result;                                                  \
    }                                                                   \
    /**/
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst, u8_findnext, _finddata_t, _wfinddata_t, _wfindfirst, _wfindnext)
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst64, u8_findnext64, __finddata64_t, _wfinddata64_t, _wfindfirst64, _wfindnext64)
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirsti64, u8_findnexti64, _finddatai64_t, _wfinddatai64_t, _wfindfirsti64, _wfindnexti64)
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst64i32, u8_findnext64i32, _finddata64i32_t, _wfinddata64i32_t, _wfindfirst64i32, _wfindnext64i32)
#ifndef _WIN64
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst32, u8_findnext32, _finddata32_t, _wfinddata32_t, _wfindfirst32, _wfindnext32)
DEFINE_U8_FINDFIRST_AND_FINDNEXT(u8_findfirst32i64, u8_findnext32i64, _finddata32i64_t, _wfinddata32i64_t, _wfindfirst32i64, _wfindnext32i64)
#endif
#undef DEFINE_U8_FINDFIRST_AND_FINDNEXT

// <direct.h>
int u8_chdir(const char *dirname)
{
    CONVERT_INPUT_TO_WCS_1(dirname, wdirname);
    RETURN_T(_wchdir(wdirname), int);
}
char *u8_getcwd(char *buffer, int maxlen)
{
    if (buffer == NULL) {
        wchar_t *wpath = _wgetcwd(NULL, maxlen);
        if (wpath == NULL) {
            return NULL;
        } else {
            size_t u8buf_len = u8conv_wcstou8_len(wpath) + 1;
            if (u8buf_len < maxlen) {
                u8buf_len = maxlen;
            }
            char *u8buf = (char *)malloc(u8buf_len * sizeof(char));
            if (u8buf == NULL) {
                free(wpath);
                _set_errno(ENOMEM);
                return NULL;
            }
            u8conv_wcstou8_cpy(u8buf, u8buf_len, wpath); // TODO: check error
            free(wpath);
            return u8buf;
        }
    } else {
        assert(maxlen > 0);
        wchar_t *wbuf = (wchar_t *)malloc(maxlen * sizeof(wchar_t));
        if (wbuf == NULL) {
            _set_errno(ENOMEM);
            return NULL;
        }
        wchar_t *wpath = _wgetcwd(wbuf, maxlen);
        if (wpath == NULL) {
            int olderrno;
            _get_errno(&olderrno);
            free(wbuf);
            _set_errno(olderrno);
            return NULL;
        }
        size_t actuallen = 0;
        u8conv_wcstou8_cpy_l(buffer, maxlen, wpath, &actuallen);
        free(wbuf);
        if (maxlen <= actuallen) {
            _set_errno(ERANGE);
            return NULL;
        }
        return buffer;
    }
}
int u8_rmdir(const char *dirname)
{
    CONVERT_INPUT_TO_WCS_1(dirname, wdirname);
    RETURN_T(_wrmdir(wdirname), int);
}
int u8_mkdir(const char *dirname)
{
    CONVERT_INPUT_TO_WCS_1(dirname, wdirname);
    RETURN_T(_wmkdir(wdirname), int);
}

// <sys/stat.h>
#define DEFINE_U8_STAT(u8_stat, _wstat, _stat) \
    int u8_stat(const char *path, struct _stat *buffer) \
    {                                                   \
        CONVERT_INPUT_TO_WCS_1(path, wpath);            \
        RETURN_T(_wstat(wpath, buffer), int);           \
    }                                                   \
    /**/
DEFINE_U8_STAT(u8_stat64, _wstat64, _stat64)
DEFINE_U8_STAT(u8_stat64i32, _wstat64i32, _stat64i32)
#ifndef _WIN64
DEFINE_U8_STAT(u8_stat32, _wstat32, _stat32)
DEFINE_U8_STAT(u8_stat32i64, _wstat32i64, _stat32i64)
#endif
#undef DEFINE_U8_STAT
