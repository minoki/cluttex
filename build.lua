--[[
  Copyright 2016 ARATA Mizuki

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

local srcdir = "src/"
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
}

local function strip_test_code(code)
  return (code:gsub("%-%- TEST CODE\n(.-)%-%- END TEST CODE\n", ""))
end

local function load_module_code(path)
  local code = strip_test_code(assert(io.open(srcdir .. path, "r")):read("*a"))
  assert(load(code)) -- Check syntax
  return code
end

local shebang = nil
local main = assert(io.open(srcdir .. "cluttex.lua", "r")):read("*a")
if main:sub(1,2) == "#!" then
  -- shebang
  shebang,main = main:match("^([^\n]+\n)(.*)$")
end

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

if default_os then
  table.insert(lines, string.format("os.type = os.type or %q\n", default_os))
end

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
table.insert(lines, main)

if outfile then
  io.output(outfile)
end
io.write(table.concat(lines, ""))
