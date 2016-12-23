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
local os = os
local os_execute = os.execute
local os_remove = os.remove
local filesys = require "lfs"
local pathutil = require "texrunner.pathutil"
local shellutil = require "texrunner.shellutil"
local escape = shellutil.escape

local copy_command
if os.type == "windows" then
  function copy_command(from, to)
    -- TODO: What if `from` begins with a slash?
    return "copy " .. escape(from) .. " " .. escape(to) .. " > NUL"
  end
else
  function copy_command(from, to)
    -- TODO: What if `from` begins with a hypen?
    return "cp " .. escape(from) .. " " .. escape(to)
  end
end

local isfile = filesys.isfile or function(path)
  return filesys.attributes(path, "mode") == "file"
end

local isdir = filesys.isdir or function(path)
  return filesys.attributes(path, "mode") == "directory"
end

local function mkdir_rec(path)
  local succ, err = filesys.mkdir(path)
  if not succ then
    succ, err = mkdir_rec(pathutil.parentdir(path))
    if succ then
      return filesys.mkdir(path)
    end
  end
  return succ, err
end

local function remove_rec(path)
  if isdir(path) then
    for file in filesys.dir(path) do
      if file ~= "." and file ~= ".." then
        local succ, err = remove_rec(pathutil.join(path, file))
        if not succ then
          return succ, err
        end
      end
    end
    return filesys.rmdir(path)
  else
    return os_remove(path)
  end
end

return {
  copy_command = copy_command,
  isfile = isfile,
  isdir = isdir,
  mkdir_rec = mkdir_rec,
  remove_rec = remove_rec,
}
