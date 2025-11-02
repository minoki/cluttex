#include "lua.h"
#include "lauxlib.h"
#include <stdbool.h>

#if defined(WIN32)
#include <windows.h>
#include <io.h> // _get_osfhandle

static bool has_embedded_zero(size_t n, const char *s)
{
    for (size_t i = 0; i < n; ++i) {
        if (s[i] == '\0') {
            return true;
        }
    }
    return false;
}

static const char *known_error_name(DWORD e)
{
    switch (e) {
    case ERROR_FILE_NOT_FOUND: return "ERROR_FILE_NOT_FOUND";
    case ERROR_PATH_NOT_FOUND: return "ERROR_PATH_NOT_FOUND";
    case ERROR_ACCESS_DENIED: return "ERROR_ACCESS_DENIED";
    case ERROR_INVALID_PARAMETER: return "ERROR_INVALID_PARAMETER";
    case ERROR_INSUFFICIENT_BUFFER: return "ERROR_INSUFFICIENT_BUFFER";
    case ERROR_ABANDONED_WAIT_0: return "ERROR_ABANDONED_WAIT_0";
    case ERROR_NOACCESS: return "ERROR_NOACCESS";
    case ERROR_INVALID_FLAGS: return "ERROR_INVALID_FLAGS";
    case ERROR_NOTIFY_ENUM_DIR: return "ERROR_NOTIFY_ENUM_DIR";
    case ERROR_NO_UNICODE_TRANSLATION: return "ERROR_NO_UNICODE_TRANSLATION";
    default: return NULL;
    }
}

static void format_error(lua_State *L, const char *name, DWORD lasterror, const char *extra)
{
    /*
    local errorname = KnownErrors[lasterror] or string.format("error code %d", lasterror)
    if extra then
        return string.format("%s failed with %s (0x%04x) [%s]", name, errorname, lasterror, extra)
    else
        return string.format("%s failed with %s (0x%04x)", name, errorname, lasterror)
    end
    */
    const char *errorname = known_error_name(lasterror);
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    luaL_addstring(&b, name);
    luaL_addstring(&b, " failed with ");
    if (errorname) {
        luaL_addstring(&b, errorname);
    } else {
        luaL_addstring(&b, "error code ");
        char buf[20];
        snprintf(buf, sizeof(buf), "%u", (unsigned int)lasterror);
        luaL_addstring(&b, buf);
    }
    char buf[10];
    snprintf(buf, sizeof(buf), " (0x%04x)", (unsigned int)lasterror);
    luaL_addstring(&b, buf);
    if (extra) {
        luaL_addstring(&b, " [");
        luaL_addstring(&b, extra);
        luaL_addstring(&b, "]");
    }
    luaL_pushresult(&b);
}

static inline bool is_lead_surrogate(WCHAR wc)
{
    return 0xD800 <= wc && wc < 0xDC00;
}

static inline bool is_trail_surrogate(WCHAR wc)
{
    return 0xDC00 <= wc && wc < 0xE000;
}

static inline bool is_surrogate(WCHAR wc)
{
    return 0xD800 <= wc && wc < 0xE000;
}

static void push_wcs_as_mbs(lua_State *L, size_t wstrlen, WCHAR wstr[])
{
    if (wstrlen == 0) {
        lua_pushliteral(L, "");
        return;
    }
    // Encode in WTF-8
    size_t mbslen = 0;
    for (size_t i = 0; i < wstrlen; ++i) {
        WCHAR wc = wstr[i];
        if (wc < 0x80) {
            mbslen += 1;
        } else if (wc < 0x800) {
            // 0b110x_xxxx 0b10xx_xxxx
            mbslen += 2;
        } else if (is_lead_surrogate(wc) && i + 1 < wstrlen && is_trail_surrogate(wstr[i + 1])) {
            // surrogate pair
            ++i;
            mbslen += 4;
        } else {
            // including orphan surrogate
            mbslen += 3;
        }
    }
    luaL_Buffer B;
    unsigned char *buf = (unsigned char *)luaL_buffinitsize(L, &B, mbslen);
    for (size_t i = 0; i < wstrlen; ++i) {
        WCHAR wc = wstr[i];
        if (wc < 0x80) {
            *buf++ = (unsigned char)wc;
        } else if (wc < 0x800) {
            // 0b110x_xxxx 0b10xx_xxxx
            *buf++ = 0xC0 | (unsigned char)(wc >> 6);
            *buf++ = 0x80 | (unsigned char)(wc & 0x3F);
        } else if (is_lead_surrogate(wc) && i + 1 < wstrlen && is_trail_surrogate(wstr[i + 1])) {
            // surrogate pair
            ++i;
            WCHAR wc2 = wstr[i];
            uint32_t codepoint = 0x10000 + (((uint32_t)(wc & 0x3FF) << 10) | (uint32_t)(wc2 & 0x3FF));
            // 0b1111_0xxx 0b10xx_xxxx 0b10xx_xxxx 0b10xx_xxxx
            *buf++ = 0xF0 | (unsigned char)(codepoint >> 18);
            *buf++ = 0x80 | (unsigned char)((codepoint >> 12) & 0x3F);
            *buf++ = 0x80 | (unsigned char)((codepoint >> 6) & 0x3F);
            *buf++ = 0x80 | (unsigned char)(codepoint & 0x3F);
        } else {
            // including orphan surrogate
            // 0b1110_xxxx 0b10xx_xxxx 0b10xx_xxxx
            *buf++ = 0xE0 | (unsigned char)(wc >> 12);
            *buf++ = 0x80 | (unsigned char)((wc >> 6) & 0x3F);
            *buf++ = 0x80 | (unsigned char)(wc & 0x3F);
        }
    }
    luaL_pushresultsize(&B, mbslen);
}

static WCHAR *push_mbs_as_wcs(lua_State *L, int arg)
{
    size_t mbslen = 0;
    const char *mbstr = luaL_checklstring(L, arg, &mbslen);
    // Decode from WTF-8
    // Invalid octets are replaced by U+FFFD
    // A pair of lone surrogates are replaced by two U+FFFDs
    size_t wcslen = 0;
    for (size_t i = 0; i < mbslen; ++i) {
        unsigned char x = (unsigned char)mbstr[i];
        if (x < 0x80) {
            wcslen += 1;
            continue;
        } else if (0xC2 <= x && x <= 0xDF) {
            // 2 bytes
            if (i + 1 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                if (0x80 <= x1 && x1 <= 0xBF) {
                    ++i;
                    wcslen += 1;
                    continue;
                }
            }
        } else if (0xE0 <= x && x <= 0xEF) {
            // 3 bytes
            if (i + 2 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                unsigned char x2 = mbstr[i + 2];
                bool ok = x == 0xE0 ? 0xA0 <= x1 && x1 <= 0xBF :
                                      0x80 <= x1 && x1 <= 0xBF;
                if (ok && 0x80 <= x2 && x2 <= 0xBF) {
                    i += 2;
                    wcslen += 1;
                    continue;
                }
            }
        } else if (0xF0 <= x && x <= 0xF4) {
            // 4 bytes
            // 0xF0      0x90-0xBF 0x80-0xBF 0x80-0xBF
            // 0xF1-0xF3 0x80-0xBF 0x80-0xBF 0x80-0xBF
            // 0xF4      0x80-0x8F 0x80-0xBF 0x80-0xBF
            if (i + 3 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                unsigned char x2 = mbstr[i + 2];
                unsigned char x3 = mbstr[i + 3];
                bool ok = x == 0xF0 ? 0x90 <= x1 && x1 <= 0xBF :
                          x == 0xF4 ? 0x80 <= x1 && x1 <= 0x8F :
                                      0x80 <= x1 && x1 <= 0xBF;
                if (ok && 0x80 <= x2 && x2 <= 0xBF && 0x80 <= x3 && x3 <= 0xBF) {
                    i += 3;
                    wcslen += 2;
                    continue;
                }
            }
        }
        // invalid: U+FFFD
        wcslen += 1;
    }
    WCHAR *buf = (WCHAR *)lua_newuserdatauv(L, (wcslen + 1) * sizeof(WCHAR), 0);
    WCHAR *ptr = buf;
    bool last_code_unit_was_lead_surrogate = false;
    for (size_t i = 0; i < mbslen; ++i) {
        bool last_code_unit_was_lead_surrogate_ = last_code_unit_was_lead_surrogate;
        last_code_unit_was_lead_surrogate = false;
        unsigned char x = (unsigned char)mbstr[i];
        if (x < 0x80) {
            *ptr++ = x;
            continue;
        } else if (0xC2 <= x && x <= 0xDF) {
            // 2 bytes
            // 0b110x_xxxx 0b10xx_xxxx
            if (i + 1 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                if (0x80 <= x1 && x1 <= 0xBF) {
                    ++i;
                    *ptr++ = ((WCHAR)(x & 0x1f) << 6) | (x1 & 0x3F);
                    continue;
                }
            }
        } else if (0xE0 <= x && x <= 0xEF) {
            // 3 bytes
            // 0b1110_xxxx 0b10xx_xxxx 0b10xx_xxxx
            if (i + 2 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                unsigned char x2 = mbstr[i + 2];
                bool ok = x == 0xE0 ? 0xA0 <= x1 && x1 <= 0xBF :
                                      0x80 <= x1 && x1 <= 0xBF;
                if (ok && 0x80 <= x2 && x2 <= 0xBF) {
                    i += 2;
                    WCHAR codepoint = ((WCHAR)(x & 0x0f) << 12) | ((WCHAR)(x1 & 0x3F) << 6) | (x2 & 0x3F);
                    if (is_surrogate(codepoint)) {
                        // orphan surrogate
                        if (is_lead_surrogate(codepoint)) {
                            last_code_unit_was_lead_surrogate = true;
                        } else if (last_code_unit_was_lead_surrogate_) {
                            *(ptr - 1) = 0xFFFD;
                            codepoint = 0xFFFD;
                        }
                    }
                    *ptr++ = codepoint;
                    continue;
                }
            }
        } else if (0xF0 <= x && x <= 0xF4) {
            // 4 bytes
            // 0b1111_0xxx 0b10xx_xxxx 0b10xx_xxxx 0b10xx_xxxx
            // 0xF0      0x90-0xBF 0x80-0xBF 0x80-0xBF
            // 0xF1-0xF3 0x80-0xBF 0x80-0xBF 0x80-0xBF
            // 0xF4      0x80-0x8F 0x80-0xBF 0x80-0xBF
            if (i + 3 < mbslen) {
                unsigned char x1 = mbstr[i + 1];
                unsigned char x2 = mbstr[i + 2];
                unsigned char x3 = mbstr[i + 3];
                bool ok = x == 0xF0 ? 0x90 <= x1 && x1 <= 0xBF :
                          x == 0xF4 ? 0x80 <= x1 && x1 <= 0x8F :
                                      0x80 <= x1 && x1 <= 0xBF;
                if (ok && 0x80 <= x2 && x2 <= 0xBF && 0x80 <= x3 && x3 <= 0xBF) {
                    i += 3;
                    uint32_t codepoint = ((uint32_t)(x & 0x0f) << 12) | ((uint32_t)(x1 & 0x3F) << 6) | (x2 & 0x3F);
                    *ptr++ = 0xD800 | ((codepoint - 0x10000) >> 10);
                    *ptr++ = 0xDC00 | (codepoint & 0x3FF);
                    continue;
                }
            }
        }
        // invalid: U+FFFD
        *ptr++ = 0xFFFD;
    }
    *ptr = 0;
    return buf;
}

static int get_full_path_name(lua_State *L)
{
    size_t filename_mbs_len = 0;
    const char *filename_mbs = luaL_checklstring(L, 1, &filename_mbs_len);
    if (has_embedded_zero(filename_mbs_len, filename_mbs)) {
        lua_pushnil(L);
        lua_pushliteral(L, "The filename contains a nul character");
        return 2;
    }
    WCHAR *filename_w = push_mbs_as_wcs(L, 1);
    WCHAR initial_buf[512];
    const DWORD initial_bufsize = 512;
    WCHAR *buf = initial_buf;
    WCHAR *filePart = NULL;
    DWORD len = 0;
    DWORD result = GetFullPathNameW(filename_w, initial_bufsize, buf, &filePart);
    // On success: `result` is the number of characters (not including the last zero)
    if (result == 0) {
        DWORD err = GetLastError();
        lua_pushnil(L);
        format_error(L, "GetFullPathNameW", err, filename_mbs);
        return 2;
    } else if (initial_bufsize < result) {
        DWORD bufsize = result; // the length including the terminating NUL character
        buf = (WCHAR *)lua_newuserdatauv(L, bufsize * sizeof(DWORD), 0);
        result = GetFullPathNameW(filename_w, initial_bufsize, buf, &filePart);
        if (result == 0) {
            DWORD err = GetLastError();
            lua_pushnil(L);
            format_error(L, "GetFullPathNameW", err, filename_mbs);
            return 2;
        } else {
            len = result < bufsize ? result : bufsize - 1;
        }
    } else {
        len = result;
    }
    push_wcs_as_mbs(L, len, buf); // fullpath
    if (filePart == NULL) {
        // directory
        lua_pushliteral(L, ""); // filePart
        lua_pushvalue(L, -2); // dirPart
    } else {
        push_wcs_as_mbs(L, buf + len - filePart, filePart); // filePart
        push_wcs_as_mbs(L, filePart - buf, buf); // dirPart
    }
    return 3;
}

struct DirWatcher {
    HANDLE handle;
    OVERLAPPED overlapped;
    unsigned char buffer[1024];
};

static int dirwatcher_gc(lua_State *L)
{
    struct DirWatcher *self = (struct DirWatcher *)luaL_checkudata(L, 1, "DirWatcher");
    if (self->handle != INVALID_HANDLE_VALUE) {
        CloseHandle(self->handle);
        self->handle = INVALID_HANDLE_VALUE;
    }
    return 0;
}

static int open_directory(lua_State *L)
{
    // arguments: dirname (string)
    size_t dirname_mbs_len = 0;
    const char *dirname_mbs = luaL_checklstring(L, 1, &dirname_mbs_len);
    if (has_embedded_zero(dirname_mbs_len, dirname_mbs)) {
        lua_pushnil(L);
        lua_pushliteral(L, "The directory name contains a nul character");
        return 2;
    }
    WCHAR *dirname_w = push_mbs_as_wcs(L, 1);
    struct DirWatcher *dirwatcher = lua_newuserdatauv(L, sizeof(struct DirWatcher), 1);
    dirwatcher->handle = INVALID_HANDLE_VALUE;
    lua_pushvalue(L, lua_upvalueindex(1)); // metatable
    lua_setmetatable(L, -2);
    lua_pushvalue(L, 1); // dirname
    lua_setiuservalue(L, -2, 1);
    const DWORD dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    const DWORD dwFlagsAndAttributes = FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED;
    HANDLE handle = CreateFileW(dirname_w, FILE_LIST_DIRECTORY, dwShareMode, NULL, OPEN_EXISTING, dwFlagsAndAttributes, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        lua_pushnil(L);
        format_error(L, "CreateFileW", err, dirname_mbs);
        return 2;
    }
    dirwatcher->handle = handle;
    return 1;
}

static int dirwatcher_start_watch(lua_State *L)
{
    // arguments: self (DirWatcher), watch_subtree (boolean)
    struct DirWatcher *self = (struct DirWatcher *)luaL_checkudata(L, 1, "DirWatcher");
    bool watch_subtree = lua_toboolean(L, 2);
    HANDLE handle = self->handle;
    void *buffer = self->buffer;
    DWORD buffer_size = sizeof(self->buffer);
    const DWORD dwNotifyFilter = FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_ATTRIBUTES | FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_LAST_ACCESS | FILE_NOTIFY_CHANGE_CREATION | FILE_NOTIFY_CHANGE_SECURITY;
    BOOL result = ReadDirectoryChangesW(handle, buffer, buffer_size, watch_subtree, dwNotifyFilter, NULL, &self->overlapped, NULL);
    if (!result) {
        DWORD err = GetLastError();
        lua_getiuservalue(L, 1, 1); // dirname
        const char *dirname = lua_tostring(L, -1);
        lua_pushnil(L);
        format_error(L, "ReadDirectoryChangesW", err, dirname);
        return 2;
    }
    lua_pushboolean(L, true);
    return 1;
}

static void push_action(lua_State *L, DWORD action)
{
    switch (action) {
    case FILE_ACTION_ADDED:
        lua_pushliteral(L, "added");
        break;
    case FILE_ACTION_REMOVED:
        lua_pushliteral(L, "removed");
        break;
    case FILE_ACTION_MODIFIED:
        lua_pushliteral(L, "modified");
        break;
    case FILE_ACTION_RENAMED_OLD_NAME:
        lua_pushliteral(L, "rename_from");
        break;
    case FILE_ACTION_RENAMED_NEW_NAME:
        lua_pushliteral(L, "rename_to");
        break;
    default:
        lua_pushnil(L);
        break;
    }
}

static int dirwatcher_process(lua_State *L)
{
    // arguments: self (DirWatcher), number_of_bytes (integer)
    struct DirWatcher *self = (struct DirWatcher *)luaL_checkudata(L, 1, "DirWatcher");
    lua_Integer i_number_of_bytes = luaL_checkinteger(L, 2);
    size_t number_of_bytes = i_number_of_bytes < (lua_Integer)sizeof(self->buffer) ? i_number_of_bytes : sizeof(self->buffer);
    unsigned char *ptr = self->buffer;
    lua_Integer i = 1;
    lua_newtable(L);
    while (number_of_bytes >= sizeof(FILE_NOTIFY_INFORMATION)) {
        FILE_NOTIFY_INFORMATION *notify_info = (FILE_NOTIFY_INFORMATION *)ptr;
        DWORD next_entry_offset = notify_info->NextEntryOffset;
        DWORD action = notify_info->Action;
        DWORD filename_length = notify_info->FileNameLength;
        lua_createtable(L, 0, 2);
        push_action(L, action);
        lua_setfield(L, -2, "action");
        push_wcs_as_mbs(L, filename_length / 2, notify_info->FileName);
        lua_setfield(L, -2, "filename");
        lua_seti(L, -2, i);
        ++i;
        if (next_entry_offset == 0 || number_of_bytes <= next_entry_offset) {
            break;
        }
        number_of_bytes -= next_entry_offset;
        ptr += next_entry_offset;
    }
    return 1;
}

struct FSWatcherPort {
    HANDLE port;
};

static int fswatcherport_gc(lua_State *L)
{
    struct FSWatcherPort *self = (struct FSWatcherPort *)luaL_checkudata(L, 1, "FSWatcherPort");
    if (self->port != INVALID_HANDLE_VALUE && self->port != NULL) {
        CloseHandle(self->port);
        self->port = NULL;
    }
    return 0;
}

static int fswatcherport_new(lua_State *L)
{
    // args: none
    struct FSWatcherPort *self = lua_newuserdatauv(L, sizeof(struct FSWatcherPort), 0);
    self->port = NULL;
    lua_pushvalue(L, lua_upvalueindex(2)); // metatable
    lua_setmetatable(L, -2);
    HANDLE port = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
    if (port == NULL) {
        DWORD err = GetLastError();
        lua_pushnil(L);
        format_error(L, "CreateIoCompletionPort", err, NULL);
        return 2;
    }
    self->port = port;
    return 1;
}

static int fswatcherport_add_directory(lua_State *L)
{
    // arguments: self (FSWatcherPort), dirwatcher (DirWatcher)
    struct FSWatcherPort *self = (struct FSWatcherPort *)luaL_checkudata(L, 1, "FSWatcherPort");
    struct DirWatcher *dirwatcher = (struct DirWatcher *)luaL_checkudata(L, 2, "DirWatcher");
    lua_Integer key = luaL_checkinteger(L, 3);
    HANDLE result = CreateIoCompletionPort(dirwatcher->handle, self->port, key, 0);
    if (result == NULL) {
        DWORD err = GetLastError();
        lua_pushnil(L);
        format_error(L, "CreateIoCompletionPort", err, NULL); // TODO: dirname?
        return 2;
    }
    lua_pushboolean(L, true);
    return 1;
}

static int fswatcherport_get_queued(lua_State *L)
{
    // arguments: self, timeout_ms (number)
    struct FSWatcherPort *self = (struct FSWatcherPort *)luaL_checkudata(L, 1, "FSWatcherPort");
    DWORD timeout_ms = 0xFFFFFFFF; // default: infinite
    if (lua_isnumber(L, 2)) {
        lua_Number n = lua_tonumber(L, 2);
        if (0.0 <= n && n <= 0xFFFFFFFF) {
            timeout_ms = (DWORD)n;
        } else if (n > 0.0) {
            timeout_ms = 0xFFFFFFFF;
        } else {
            timeout_ms = 0;
        }
    }
    DWORD number_of_bytes = 0;
    ULONG_PTR completion_key = 0;
    OVERLAPPED *ptr_overlapped = NULL;
    BOOL result = GetQueuedCompletionStatus(self->port, &number_of_bytes, &completion_key, &ptr_overlapped, timeout_ms);
    if (!result) {
        DWORD err = GetLastError();
        lua_pushnil(L);
        if (err == WAIT_TIMEOUT) {
            lua_pushliteral(L, "timeout");
        } else {
            format_error(L, "GetQueuedCompletionStatus", err, NULL);
        }
        return 2;
    }
    lua_pushinteger(L, number_of_bytes);
    lua_pushinteger(L, completion_key);
    return 2;
}

static int get_tick_count(lua_State *L)
{
    lua_pushinteger(L, GetTickCount64());
    return 1;
}

static const luaL_Reg dirwatcher_meta[] = {
    {"__gc", dirwatcher_gc},
    {"close", dirwatcher_gc},
    {"start_watch", dirwatcher_start_watch},
    {"process", dirwatcher_process},
    {NULL, NULL},
};

static const luaL_Reg fswatcherport_meta[] = {
    {"__gc", fswatcherport_gc},
    {"close", fswatcherport_gc},
    {"add_directory", fswatcherport_add_directory},
    {"get_queued", fswatcherport_get_queued},
    {NULL, NULL},
};

static const luaL_Reg funcs[] = {
    {"open_directory", open_directory},
    {"new_port", fswatcherport_new},
    {"get_full_path_name", get_full_path_name},
    {"get_tick_count", get_tick_count},
    {NULL, NULL},
};

int luaopen_fswatcher_c(lua_State *L)
{
    lua_createtable(L, 0, 3);

    luaL_newmetatable(L, "DirWatcher");
    luaL_setfuncs(L, dirwatcher_meta, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    luaL_newmetatable(L, "FSWatcherPort");
    luaL_setfuncs(L, fswatcherport_meta, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    luaL_setfuncs(L, funcs, 2);
    return 1;
}

#endif
