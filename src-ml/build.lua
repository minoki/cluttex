--[[
  Copyright 2016, 2018 ARATA Mizuki

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
local default_os
if arg[1] == "--unix-shellscript" then
  default_os, mode = "unix", "shellscript"
  table.remove(arg, 1)
elseif arg[1] == "--windows-batchfile" then
  default_os, mode = "windows", "batchfile"
  table.remove(arg, 1)
end
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
    name = "texrunner.luatexinit",
    path = "texrunner/luatexinit.lua",
  },
  {
    name = "texrunner.isatty",
    path = "texrunner/isatty.lua",
  },
  {
    name = "texrunner.fswatcher_windows",
    path = "texrunner/fswatcher_windows.lua",
  },
}

local imported_globals = {"io", "os", "string", "table", "package", "require", "assert", "error", "ipairs", "type", "select", "arg"}

-- TODO: This code may interfere with the string literal embedded in luatexinit.lua
local function strip_global_imports(code)
  local function repl(s1, s2)
    if s1 == s2 then
      for i, v in ipairs(imported_globals) do
        if v == s1 then
          return ""
        end
      end
    end
    return nil
  end
  return (code:gsub("local (%w+) = (%w+)\n", repl))
end

local function strip_test_code(code)
  if preserve_location_info then
    return (code:gsub("%-%- TEST CODE\n.-%-%- END TEST CODE\n", function(s)
      return (s:gsub("[^\n]",""))
    end))
  else
    return (code:gsub("%-%- TEST CODE\n(.-)%-%- END TEST CODE\n", ""))
  end
end

local function load_module_code(path)
  assert(loadfile(srcdir .. path)) -- Check syntax
  return strip_test_code(assert(io.open(srcdir .. path, "r")):read("*a"))
end

assert(loadfile("cluttex-ml.lua")) -- Check syntax

local shebang = "#!/usr/bin/env texlua\n"
local main = assert(io.open("cluttex-ml.lua", "r")):read("*a")
--[[
if main:sub(1,2) == "#!" then
  -- shebang
  shebang,main = main:match("^([^\n]+\n)(.*)$")
end
]]

local lines = {}
if mode == "batchfile" then
  lines[1] = [=[
::dummy:: --[[
@texlua "%~f0" %*
@goto :eof
]]
]=]
else
  if shebang then
    lines[1] = shebang
  end
end

if not preserve_location_info then
  table.insert(lines, string.format("local %s = %s\n", table.concat(imported_globals, ", "), table.concat(imported_globals, ", ")))
end

if default_os then
  table.insert(lines, string.format("os.type = os.type or %q\n", default_os))
end

-- LuajitTeX doesn't seem to set package.loaded table...
table.insert(lines, "if lfs and not package.loaded['lfs'] then package.loaded['lfs'] = lfs end\n")
if preserve_location_info then
  table.insert(lines, "local loadstring = loadstring or load\n")
  for _,m in ipairs(modules) do
    if m.path_windows or m.path_unix then
      table.insert(lines, 'if os.type == "windows" then\n')
      table.insert(lines, string.format("package.preload[%q] = assert(loadstring(%q, %q))\n", m.name, load_module_code(m.path_windows or m.path), "=" .. (m.path_windows or m.path)))
      table.insert(lines, 'else\n')
      table.insert(lines, string.format("package.preload[%q] = assert(loadstring(%q, %q))\n", m.name, load_module_code(m.path_unix or m.path), "=" .. (m.path_unix or m.path)))
      table.insert(lines, 'end\n')
    else
      table.insert(lines, string.format("package.preload[%q] = assert(loadstring(%q, %q))\n", m.name, load_module_code(m.path), "=" .. m.path))
    end
  end
  table.insert(lines, string.format("assert(loadstring(%q, %q))(...)\n", main, "=cluttex.lua"))
else
  for _,m in ipairs(modules) do
    if m.path_windows or m.path_unix then
      table.insert(lines, 'if os.type == "windows" then\n')
      table.insert(lines, string.format("package.preload[%q] = function(...)\n%send\n", m.name, load_module_code(m.path_windows or m.path)))
      table.insert(lines, 'else\n')
      table.insert(lines, string.format("package.preload[%q] = function(...)\n%send\n", m.name, load_module_code(m.path_unix or m.path)))
      table.insert(lines, 'end\n')
    else
      table.insert(lines, string.format("package.preload[%q] = function(...)\n%send\n", m.name, load_module_code(m.path)))
    end
  end
  table.insert(lines, strip_global_imports(main))
end

if outfile then
  io.output(assert(io.open(outfile, "wb")))
end
io.write(table.concat(lines, ""))
