--[[
  Copyright 2016,2019 ARATA Mizuki

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

local string_gsub = string.gsub
local os_execute = os.execute

-- s: string
local function escape(s)
  return '"' .. string_gsub(string_gsub(s, '(\\*)"', '%1%1\\"'), '(\\+)$', '%1%1') .. '"'
end

-- TEST CODE
assert(escape([[Hello world!]]) == [["Hello world!"]])
assert(escape([[Hello" world!]]) == [["Hello\" world!"]])
assert(escape([[Hello\" world!"]]) == [["Hello\\\" world!\""]])
-- END TEST CODE

local function has_command(name)
  local result = os_execute("where " .. escape(name) .. " > NUL 2>&1")
  -- Note that os.execute returns a number on Lua 5.1 or LuaTeX
  return result == 0 or result == true
end

return {
  escape = escape,
  has_command = has_command,
}
