if #arg < 2 then
  io.stderr:write("embedlua.lua <source.lua> <target.c>\n")
end
local sourcename = arg[1]
local targetname = arg[2]
local sourcef = assert(io.open(sourcename))
local source = sourcef:read("*a")
sourcef:close()
assert(load(source, "="..sourcename))
local basename = assert(string.match(sourcename, "^([%w%.]+)%.lua$"), "invalid module name")
local modname = string.gsub(basename, "%.", "_")
local targetf = assert(io.open(targetname, "w"))
targetf:write([[
/* This file was automatically generated embedlua.lua. */
#include "lua.h"
#include "lauxlib.h"

static const char code[] = ""
]])
local t = {[" "] = " ", ["\t"] = [[\t]], ['"'] = [[\"]], ["\\"] = [[\\]]}
for l in string.gmatch(source, "[^\r\n]*") do
  local ll = l:gsub(".", function(c)
    if t[c] then
      return t[c]
    elseif c:match("%g") then
      return c
    else
      local b = string.byte(c, 1)
      return string.format("\\x%02x", b)
    end
  end)
  targetf:write(string.format(" \"%s\\n\"\n", ll))
end
targetf:write(string.format([[
;

int luaopen_%s(lua_State *L) {
    int n = lua_gettop(L);
    if (luaL_loadbuffer(L, code, sizeof(code)-1, "=%s") != LUA_OK) {
        return lua_error(L);
    }
    if (n >= 1) {
        lua_pushvalue(L, 1); /* module name */
        lua_call(L, 1, 1);
    } else {
        lua_call(L, 0, 1);
    }
    return 1;
}
]], modname, sourcename))
