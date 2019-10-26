#include "lprefix.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

extern int luaopen_lfs(lua_State *L);

static int isfile(lua_State *L)
{
    return 0;
}

static int isdir(lua_State *L)
{
    return 0;
}

int luaopen_lfsext(lua_State *L)
{
    luaL_requiref(L, "lfs", luaopen_lfs, 0);
return 1;
}
