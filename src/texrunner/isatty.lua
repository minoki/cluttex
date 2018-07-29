--[[
  Copyright 2018 ARATA Mizuki

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

if os.type == "unix" then
  -- try luaposix
  local succ, M = pcall(function()
      local posix_unistd = require "posix.unistd"
      local posix_stdio = require "posix.stdio"
      return {
        isatty = function(file)
          return posix_unistd.isatty(posix_stdio.fileno(file)) == 1
        end,
      }
  end)
  if succ then
    return M
  end

  -- try LuaJIT
  local succ, M = pcall(function()
      local ffi = require "ffi"
      ffi.cdef[[
int isatty(int fd);
int fileno(void *stream);
]]
      local isatty = assert(ffi.C.isatty, "isatty not found")
      local fileno = assert(ffi.C.fileno, "fileno not found")
      return {
        isatty = function(file)
          -- LuaJIT converts Lua's file handles into FILE* (void*)
          return isatty(fileno(file)) == 1
        end
      }
  end)
  if succ then
    return M
  end

else
  -- Windows: not supported
end

return {
  isatty = function(file)
    return false
  end,
}
