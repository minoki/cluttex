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
  -- Try luaposix
  local succ, M = pcall(function()
      local isatty = require "posix.unistd".isatty
      local fileno = require "posix.stdio".fileno
      return {
        isatty = function(file)
          return isatty(fileno(file)) == 1
        end,
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via luaposix\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: luaposix not found: ", M, "\n")
    end
  end

  -- Try LuaJIT-like FFI
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
          return isatty(fileno(file)) ~= 0
        end
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via FFI (Unix)\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: FFI (Unix) not found: ", M, "\n")
    end
  end

else
  -- Try LuaJIT
  -- TODO: Try to detect MinTTY using GetFileInformationByHandleEx
  local succ, M = pcall(function()
      local ffi = require "ffi"
      local bitlib = assert(bit32 or bit, "Neither bit32 (Lua 5.2) nor bit (LuaJIT) found") -- Lua 5.2 or LuaJIT
      ffi.cdef[[
int _isatty(int fd);
int _fileno(void *stream);
void *_get_osfhandle(int fd); // should return intptr_t
typedef int BOOL;
typedef uint32_t DWORD;
typedef int FILE_INFO_BY_HANDLE_CLASS; // ???
typedef struct _FILE_NAME_INFO {
DWORD FileNameLength;
uint16_t FileName[?];
} FILE_NAME_INFO;
DWORD GetFileType(void *hFile);
BOOL GetFileInformationByHandleEx(void *hFile, FILE_INFO_BY_HANDLE_CLASS fic, void *fileinfo, DWORD dwBufferSize);
BOOL GetConsoleMode(void *hConsoleHandle, DWORD* lpMode);
BOOL SetConsoleMode(void *hConsoleHandle, DWORD dwMode);
]]
      local isatty = assert(ffi.C._isatty, "_isatty not found")
      local fileno = assert(ffi.C._fileno, "_fileno not found")
      local get_osfhandle = assert(ffi.C._get_osfhandle, "_get_osfhandle not found")
      local GetFileType = assert(ffi.C.GetFileType, "GetFileType not found")
      local GetFileInformationByHandleEx = assert(ffi.C.GetFileInformationByHandleEx, "GetFileInformationByHandleEx not found")
      local GetConsoleMode = assert(ffi.C.GetConsoleMode, "GetConsoleMode not found")
      local SetConsoleMode = assert(ffi.C.SetConsoleMode, "SetConsoleMode not found")
      local function wide_to_narrow(array, length)
        local t = {}
        for i = 0, length - 1 do
          table.insert(t, string.char(math.min(array[i], 0xff)))
        end
        return table.concat(t, "")
      end
      local function is_mintty(fd)
        local handle = get_osfhandle(fd)
        local filetype = GetFileType(handle)
        if filetype ~= 0x0003 then -- not FILE_TYPE_PIPE (0x0003)
          -- mintty must be a pipe
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: not a pipe\n")
          end
          return false
        end
        local nameinfo = ffi.new("FILE_NAME_INFO", 32768)
        local FileNameInfo = 2 -- : FILE_INFO_BY_HANDLE_CLASS
        if GetFileInformationByHandleEx(handle, FileNameInfo, nameinfo, ffi.sizeof("FILE_NAME_INFO", 32768)) ~= 0 then
          local filename = wide_to_narrow(nameinfo.FileName, math.floor(nameinfo.FileNameLength / 2))
          -- \(cygwin|msys)-<hex digits>-pty<N>-(from|to)-master
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: GetFileInformationByHandleEx returned ", filename, "\n")
          end
          local a, b = string.match(filename, "^\\(%w+)%-%x+%-pty%d+%-(%w+)%-master$")
          if (a == "cygwin" or a == "msys") and (b == "from" or b == "to") then
            return true
          end
        else
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: GetFileInformationByHandleEx failed\n")
          end
        end
        return false
      end
      return {
        isatty = function(file)
          -- LuaJIT converts Lua's file handles into FILE* (void*)
          local fd = fileno(file)
          return isatty(fd) ~= 0 or is_mintty(fd)
        end,
        enable_console_colors = function(file)
          local fd = fileno(file)
          if isatty(fd) ~= 0 then
            local handle = get_osfhandle(fd)
            local modePtr = ffi.new("DWORD[1]")
            local result = GetConsoleMode(handle, modePtr)
            if result ~= 0 then
              local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
              result = SetConsoleMode(handle, bitlib.bor(modePtr[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING))
              if result == 0 then
                if CLUTTEX_VERBOSITY >= 3 then
                  io.stderr:write("ClutTeX: SetConsoleMode failed\n")
                end
              end
            else
              if CLUTTEX_VERBOSITY >= 3 then
                io.stderr:write("ClutTeX: GetConsoleMode failed\n")
              end
            end
          end
        end,
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via FFI (Windows)\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: FFI (Windows) not found: ", M, "\n")
    end
  end
end

return {
  isatty = function(file)
    return false
  end,
}
