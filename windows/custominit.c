#define linit_c
#define LUA_LIB

#include "lprefix.h"

#include <stddef.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

extern int luaopen_lfs(lua_State *L);
extern int luaopen_md5_core(lua_State *L);
extern int luaopen_md5(lua_State *L);
extern int luaopen_ffi(lua_State *L);
extern int luaopen_osext(lua_State *L);
extern int luaopen_isatty(lua_State *L);

static const luaL_Reg loadedlibs[] = {
    {"_G", luaopen_base},
    {LUA_LOADLIBNAME, luaopen_package},
    {LUA_COLIBNAME, luaopen_coroutine},
    {LUA_TABLIBNAME, luaopen_table},
    {LUA_IOLIBNAME, luaopen_io},
    {LUA_OSLIBNAME, luaopen_osext},
    {LUA_STRLIBNAME, luaopen_string},
    {LUA_MATHLIBNAME, luaopen_math},
    {LUA_UTF8LIBNAME, luaopen_utf8},
    {LUA_DBLIBNAME, luaopen_debug},
#if defined(LUA_COMPAT_BITLIB)
    {LUA_BITLIBNAME, luaopen_bit32},
#endif
    {NULL, NULL}
};

static const luaL_Reg preloads[] = {
    {"lfs", luaopen_lfs},
    {"md5.core", luaopen_md5_core},
    {"md5", luaopen_md5},
    {"ffi", luaopen_ffi},
    {"texrunner.isatty", luaopen_isatty},
    {NULL, NULL}
};

LUALIB_API void luaL_openlibs (lua_State *L)
{
    const luaL_Reg *lib;
    for (lib = loadedlibs; lib->func; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1);
    }
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    for (lib = preloads; lib->func; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
}
