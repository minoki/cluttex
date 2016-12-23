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

local assert = assert
local string_match = string.match
local table = table
local table_insert = table.insert
local table_concat = table.concat

-- s: string
local function escape(s)
  local len = #s
  local result = {}
  local t,i = string_match(s, "^([^']*)()")
  assert(t)
  if t ~= "" then
    table_insert(result, "'")
    table_insert(result, t)
    table_insert(result, "'")
  end
  while i < len do
    t,i = string_match(s, "^('+)()", i)
    assert(t)
    table_insert(result, '"')
    table_insert(result, t)
    table_insert(result, '"')
    t,i = string_match(s, "^([^']*)()", i)
    assert(t)
    if t ~= "" then
      table_insert(result, "'")
      table_insert(result, t)
      table_insert(result, "'")
    end
  end
  return table_concat(result, "")
end

-- TEST CODE
assert(escape([[Hello world!]]) == [['Hello world!']])
assert(escape([[Hello' world!]]) == [['Hello'"'"' world!']])
assert(escape([[Hello' world!"]]) == [['Hello'"'"' world!"']])
-- END TEST CODE

return {
  escape = escape,
}
