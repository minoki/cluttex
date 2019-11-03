#include "lua.h"
#include "lauxlib.h"
#include <stdbool.h>

#if defined(WIN32)
#include <windows.h>
#include <io.h> // _get_osfhandle

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

static bool is_mintty(HANDLE handle) {
    DWORD filetype = GetFileType(handle);
    if (filetype != FILE_TYPE_PIPE /*0x0003*/) {
        // not a pipe
        return false;
    }
    union {
        FILE_NAME_INFO filenameinfo;
        struct {
            DWORD FileNameLength;
            WCHAR FileName[256];
        } buffer;
    } u;
    if (!GetFileInformationByHandleEx(handle, FileNameInfo, &u.filenameinfo, sizeof(u))) {
        return false;
    }
    // \(cygwin|msys)-<hex digits>-pty<N>-(from|to)-master
    DWORD len = min(sizeof(u) - sizeof(u.filenameinfo.FileNameLength) - sizeof(WCHAR), u.filenameinfo.FileNameLength) / 2;
    u.filenameinfo.FileName[len] = L'\0';
    WCHAR *filename = u.filenameinfo.FileName;
    if (*filename++ != L'\\') {
        return false;
    }
    if (wcsncmp(filename, L"msys", 4) == 0) {
        filename += 4;
    } else if (wcsncmp(filename, L"cygwin", 6) == 0) {
        filename += 6;
    } else {
        return false;
    }
    if (*filename++ != L'-') {
        return false;
    }
    while (iswxdigit(*filename)) ++filename;
    if (wcsncmp(filename, L"-pty", 4) != 0) {
        return false;
    }
    filename += 4;
    while (iswdigit(*filename)) ++filename;
    return wcscmp(filename, L"-from-master") == 0 || wcscmp(filename, L"-to-master") == 0;
}

/* isatty(f: stream): boolean */
static int l_isatty(lua_State *L) {
    luaL_Stream *stream = (luaL_Stream *)luaL_checkudata(L, 1, LUA_FILEHANDLE);
    int fd = _fileno(stream->f);
    lua_pushboolean(L, _isatty(fd) || is_mintty((HANDLE)_get_osfhandle(fd)));
    return 1;
}

/* enable_virtual_terminal(f: stream): boolean [, reason] */
static int l_enablevt(lua_State *L) {
    luaL_Stream *stream = (luaL_Stream *)luaL_checkudata(L, 1, LUA_FILEHANDLE);
    int fd = _fileno(stream->f);
    HANDLE handle = (HANDLE)_get_osfhandle(fd);
    if (is_mintty(handle)) {
        lua_pushboolean(L, 1);
        lua_pushliteral(L, "mintty");
        return 2;
    } else if (_isatty(fd)) {
        const wchar_t *ConEmuANSI = _wgetenv(L"ConEmuANSI");
        if (ConEmuANSI != NULL && wcscmp(ConEmuANSI, L"ON") == 0) {
            lua_pushboolean(L, 1);
            lua_pushliteral(L, "conemu");
            return 2;
        } else if (_wgetenv(L"ANSICON") != NULL) {
            lua_pushboolean(L, 1);
            lua_pushliteral(L, "ansicon");
            return 2;
        } else {
            DWORD mode = 0;
            BOOL result = GetConsoleMode(handle, &mode);
            if (result == 0) {
                lua_pushboolean(L, 0);
                // TODO: push last error?
                lua_pushliteral(L, "GetConsoleMode failed");
                return 2;
            }
            result = SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
            if (result == 0) {
                lua_pushboolean(L, 0);
                // TODO: push last error?
                lua_pushliteral(L, "SetConsoleMode failed");
                // Typical error code: ERROR_INVALID_PARAMETER (0x57)
                return 2;
            }
            lua_pushboolean(L, 1);
            lua_pushliteral(L, "native");
            return 2;
        }
    } else {
        lua_pushboolean(L, 0);
        lua_pushliteral(L, "not a tty");
        return 2;
    }
}

static const luaL_Reg funcs[] = {
    {"isatty", l_isatty},
    {"enable_virtual_terminal", l_enablevt},
    {NULL, NULL}
};

#else // Assume Unix
#include <unistd.h>

/* isatty(f: stream): boolean */
static int l_isatty(lua_State *L) {
    luaL_Stream *stream = (luaL_Stream *)luaL_checkudata(L, 1, LUA_FILEHANDLE);
    int fd = fileno(stream->f);
    lua_pushboolean(L, isatty(fd));
    return 1;
}

static const luaL_Reg funcs[] = {
    {"isatty", l_isatty},
    {NULL, NULL}
};

#endif

int luaopen_isatty(lua_State *L) {
    luaL_newlibtable(L, funcs);
    luaL_setfuncs(L, funcs, 0);
    return 1;
}
