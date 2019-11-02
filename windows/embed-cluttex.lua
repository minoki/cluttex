--[[
  Copyright 2019 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local srcdir = "../src/"
local mode
local outfile = arg[1]
local preserve_location_info = false

local modules = {
  {
    name = "texrunner.pathutil",
    path = "texrunner/pathutil.lua",
    path_unix = "texrunner/pathutil_unix.lua",
    path_windows = "texrunner/pathutil_windows.lua",
  },
  {
    name = "texrunner.shellutil",
    path = "texrunner/shellutil.lua",
    path_unix = "texrunner/shellutil_unix.lua",
    path_windows = "texrunner/shellutil_windows.lua",
  },
  {
    name = "texrunner.fsutil",
    path = "texrunner/fsutil.lua",
  },
  {
    name = "texrunner.option",
    path = "texrunner/option.lua",
  },
  {
    name = "texrunner.tex_engine",
    path = "texrunner/tex_engine.lua",
  },
  {
    name = "texrunner.reruncheck",
    path = "texrunner/reruncheck.lua",
  },
  {
    name = "texrunner.auxfile",
    path = "texrunner/auxfile.lua",
  },
  {
    name = "texrunner.luatexinit",
    path = "texrunner/luatexinit.lua",
  },
  {
    name = "texrunner.recovery",
    path = "texrunner/recovery.lua",
  },
  {
    name = "texrunner.handleoption",
    path = "texrunner/handleoption.lua",
  },
  --[[
  {
    name = "texrunner.isatty",
    path = "texrunner/isatty.lua",
  },
  ]]
  {
    name = "texrunner.message",
    path = "texrunner/message.lua",
  },
  {
    name = "texrunner.fswatcher_windows",
    path = "texrunner/fswatcher_windows.lua",
  },
  {
    name = "texrunner.safename",
    path = "texrunner/safename.lua",
  },
}

local function strip_test_code(code)
  return (code:gsub("%-%- TEST CODE\n.-%-%- END TEST CODE\n", function(s)
    return (s:gsub("[^\n]",""))
  end))
end

local function load_module_code(path)
  assert(loadfile(srcdir .. path)) -- Check syntax
  return strip_test_code(assert(io.open(srcdir .. path, "r")):read("*a"))
end

local function escapemodulename(name)
  return (name:gsub("[^%w_]", "_"))
end

local function escapesource(name, source)
  local buf = {}
  table.insert(buf, string.format("static const char %s[] = \"\"\n", name))
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
    table.insert(buf, " \"")
    table.insert(buf, ll)
    table.insert(buf, "\\n\"\n")
  end
  table.insert(buf, ";\n")
  return table.concat(buf, "")
end

local targetname = "cluttex-luapart.c"
local targetf = assert(io.open(targetname, "w"))
targetf:write([[
/* This file was automatically generated embed-cluttex.lua. */
#include "lua.h"
#include "lauxlib.h"

]])

for _,m in ipairs(modules) do
  local srcvar = "source_" .. escapemodulename(m.name)
  local path = m.path_windows or m.path
  local code = load_module_code(path)
  targetf:write(escapesource(srcvar, code))
end

do
  assert(loadfile(srcdir .. "cluttex.lua")) -- Check syntax
  local main = assert(io.open(srcdir .. "cluttex.lua", "r")):read("*a")
  if main:sub(1,2) == "#!" then
    -- shebang
    main = "--" .. main
  end
  targetf:write(escapesource("source_cluttex_main", main))
end

targetf:write(string.format([[

struct LuaModuleCode {
    const char *modname;
    const char *sourcename;
    const char *code;
    size_t code_length;
};
static struct LuaModuleCode preloads[] = {
]]))
for _,m in ipairs(modules) do
  local srcvar = "source_" .. escapemodulename(m.name)
  local path = m.path_windows or m.path
  targetf:write(string.format("    {\"%s\", \"=%s\", %s, sizeof(%s)-1},\n", m.name, path, srcvar, srcvar))
end
targetf:write([[
    {NULL, NULL, NULL, 0}
};

int setup_cluttex_modules(lua_State *L) {
    struct LuaModuleCode *lib = NULL;
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE); /* push package.preload */
    for (lib = preloads; lib->modname; lib++) {
        if (luaL_loadbuffer(L, lib->code, lib->code_length, lib->sourcename) != LUA_OK) {
            return lua_error(L);
        }
        lua_setfield(L, -2, lib->modname); /* package.preload[name] = module */
    }
    lua_pop(L, 1); /* pop package.preload */
    return 0;
}

int load_cluttex(lua_State *L) {
    if (luaL_loadbuffer(L, source_cluttex_main, sizeof(source_cluttex_main)-1, "cluttex.lua") != LUA_OK) {
        return lua_error(L);
    }
    return 1;
}
]])

do
  local depsfile = assert(io.open("cluttex-luapart-deps.mk", "w"))
  local luafiles = {srcdir .. "cluttex.lua"}
  for _,m in ipairs(modules) do
    table.insert(luafiles, srcdir .. (m.path_windows or m.path))
  end
  depsfile:write(targetname, ": ", table.concat(luafiles, " "), "\n")
  depsfile:close()
end
