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

local use_colors = false

local function set_colors(mode)
  local M
  if mode == "always" then
    M = require "texrunner.isatty"
    use_colors = true
    if use_colors and M.enable_virtual_terminal then
      local succ = M.enable_virtual_terminal(io.stderr)
      if not succ and CLUTTEX_VERBOSITY >= 2 then
        io.stderr:write("ClutTeX: Failed to enable virtual terminal\n")
      end
    end
  elseif mode == "auto" then
    M = require "texrunner.isatty"
    use_colors = M.isatty(io.stderr)
    if use_colors and M.enable_virtual_terminal then
      use_colors = M.enable_virtual_terminal(io.stderr)
      if not use_colors and CLUTTEX_VERBOSITY >= 2 then
        io.stderr:write("ClutTeX: Failed to enable virtual terminal\n")
      end
    end
  elseif mode == "never" then
    use_colors = false
  else
    error "The value of --color option must be one of 'auto', 'always', or 'never'."
  end
end

-- ESCAPE: hex 1B = dec 27 = oct 33

local CMD = {
  reset      = "\027[0m",
  underline  = "\027[4m",
  fg_black   = "\027[30m",
  fg_red     = "\027[31m",
  fg_green   = "\027[32m",
  fg_yellow  = "\027[33m",
  fg_blue    = "\027[34m",
  fg_magenta = "\027[35m",
  fg_cyan    = "\027[36m",
  fg_white   = "\027[37m",
  fg_reset   = "\027[39m",
  bg_black   = "\027[40m",
  bg_red     = "\027[41m",
  bg_green   = "\027[42m",
  bg_yellow  = "\027[43m",
  bg_blue    = "\027[44m",
  bg_magenta = "\027[45m",
  bg_cyan    = "\027[46m",
  bg_white   = "\027[47m",
  bg_reset   = "\027[49m",
  fg_x_black   = "\027[90m",
  fg_x_red     = "\027[91m",
  fg_x_green   = "\027[92m",
  fg_x_yellow  = "\027[93m",
  fg_x_blue    = "\027[94m",
  fg_x_magenta = "\027[95m",
  fg_x_cyan    = "\027[96m",
  fg_x_white   = "\027[97m",
  bg_x_black   = "\027[100m",
  bg_x_red     = "\027[101m",
  bg_x_green   = "\027[102m",
  bg_x_yellow  = "\027[103m",
  bg_x_blue    = "\027[104m",
  bg_x_magenta = "\027[105m",
  bg_x_cyan    = "\027[106m",
  bg_x_white   = "\027[107m",
}

local function exec_msg(commandline)
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[EXEC]", CMD.reset, " ", CMD.fg_cyan, commandline, CMD.reset, "\n")
  else
    io.stderr:write("[EXEC] ", commandline, "\n")
  end
end

local function error_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[ERROR]", CMD.reset, " ", CMD.fg_red, message, CMD.reset, "\n")
  else
    io.stderr:write("[ERROR] ", message, "\n")
  end
end

local function warn_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[WARN]", CMD.reset, " ", CMD.fg_blue, message, CMD.reset, "\n")
  else
    io.stderr:write("[WARN] ", message, "\n")
  end
end

local function diag_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[DIAG]", CMD.reset, " ", CMD.fg_blue, message, CMD.reset, "\n")
  else
    io.stderr:write("[DIAG] ", message, "\n")
  end
end

local function info_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[INFO]", CMD.reset, " ", CMD.fg_magenta, message, CMD.reset, "\n")
  else
    io.stderr:write("[INFO] ", message, "\n")
  end
end

return {
  set_colors = set_colors,
  exec  = exec_msg,
  error = error_msg,
  warn  = warn_msg,
  diag  = diag_msg,
  info  = info_msg,
}
