#define LUA_LIB

#include "lprefix.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

static int os_setenv(lua_State *L)
{
    const char *key = luaL_checkstring(L, 1);
    const char *value = luaL_optstring(L, 2, NULL);
#ifdef _WIN32
    char *buffer = NULL;
    size_t buffer_size = 0;
    char buffer_static[1024];
    buffer_size = strlen(key) + (value == NULL ? 0 : strlen(value)) + 2;
    if (buffer_size > sizeof(buffer_static)) {
        buffer = lua_newuserdata(L, buffer_size);
    } else {
        buffer = buffer_static;
    }
    if (value == NULL) {
        snprintf(buffer, buffer_size, "%s=", key);
    } else {
        snprintf(buffer, buffer_size, "%s=%s", key, value);
    }
    if (_putenv(buffer) != 0) {
        return luaL_error(L, "unable to change environment");
    }
#else
    if (value == NULL) {
        unsetenv(key);
    } else {
        setenv(key, value);
    }
#endif
    lua_pushboolean(L, 1);
    return 1;
}

int luaopen_osext (lua_State *L)
{
    luaL_requiref(L, LUA_OSLIBNAME, luaopen_os, 0);
    lua_pushcfunction(L, os_setenv);
    lua_setfield(L, -2, "setenv");
#ifdef _WIN32
    lua_pushliteral(L, "windows");
#else
    lua_pushliteral(L, "unix");
#endif
    lua_setfield(L, -2, "type"); /* set 'os.type' */
    return 1;
}
