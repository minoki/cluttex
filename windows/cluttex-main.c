#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

extern int setup_cluttex_modules(lua_State *L);
extern int load_cluttex(lua_State *L);

static void setup_arg(lua_State *L, int argc, char **argv) {
    lua_createtable(L, argc - 1, 1);
    for (int i = 0; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
}

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    char **argv = (char **)lua_touserdata(L, 2);
    luaL_openlibs(L);
    setup_cluttex_modules(L);
    setup_arg(L, argc, argv);
    // TODO: set os.utf8?
    load_cluttex(L);
    for (int i = 1; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
    }
    lua_call(L, argc - 1, 0);
    return 0;
}

int main(int argc, char *argv[]) {
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        return 1;
    }
    lua_pushcfunction(L, &pmain);
    lua_pushinteger(L, argc);
    lua_pushlightuserdata(L, argv);
    int result = lua_pcall(L, 2, 0, 0);
    if (result != LUA_OK) {
        const char *err = lua_tostring(L, -1);
        fprintf(stderr, "Lua error: %s %s\n", result == LUA_ERRRUN ? "runtime error" : result == LUA_ERRMEM ? "memory error" : result == LUA_ERRERR ? "message handler" : result == LUA_ERRGCMM ? "GC metamethod" : "unknown", err);
    }
    lua_close(L);
    return result == LUA_OK ? 0 : 1;
}
