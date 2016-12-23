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

local io = io
local assert = assert
local filesys = require "lfs"
local md5 = require "md5"
local fsutil = require "texrunner.fsutil"
local pathutil = require "texrunner.pathutil"

local function md5sum_file(path)
  local f = assert(io.open(path, "rb"))
  local contents = f:read("*a")
  f:close()
  return md5.sum(contents)
end

-- filelist = parse_recorder_file("jobname.fls")
-- filelist[i] = {path = "...", abspath = "...", kind = "input" or "output" or "auxiliary"}
local function parse_recorder_file(file)
  local filelist = {}
  local filemap = {}
  for l in io.lines(file) do
    local t,path = l:match("^(%w+) (.*)$")
    if t == "PWD" then
      -- Ignore

    elseif t == "INPUT" then
      local abspath = pathutil.abspath(path)
      local fileinfo = filemap[abspath]
      if not fileinfo then
        if fsutil.isfile(path) then
          fileinfo = {path = path, abspath = abspath, kind = "input"}
          table.insert(filelist, fileinfo)
          filemap[abspath] = fileinfo
        else
          -- Maybe a command execution
        end
      else
        if #path < #fileinfo.path then
          fileinfo.path = path
        end
        if fileinfo.kind == "output" then
          -- The files listed in both INPUT and OUTPUT are considered to be auxiliary files.
          fileinfo.kind = "auxiliary"
        end
      end

    elseif t == "OUTPUT" then
      local abspath = pathutil.abspath(path)
      local fileinfo = filemap[abspath]
      if not fileinfo then
        fileinfo = {path = path, abspath = abspath, kind = "output"}
        table.insert(filelist, fileinfo)
        filemap[abspath] = fileinfo
      else
        if #path < #fileinfo.path then
          fileinfo.path = path
        end
        if fileinfo.kind == "input" then
          -- The files listed in both INPUT and OUTPUT are considered to be auxiliary files.
          fileinfo.kind = "auxiliary"
        end
      end

    else
      io.stderr:write("cluttex warning: Unrecognized line in recorder file '", file, "': ", l, "\n")
    end
  end
  return filelist
end

-- auxstatus = collectfileinfo(filelist [, auxstatus])
local function collectfileinfo(filelist, auxstatus)
  auxstatus = auxstatus or {}
  for i,fileinfo in ipairs(filelist) do
    local path = fileinfo.abspath
    if fsutil.isfile(path) then
      local status = auxstatus[path] or {}
      auxstatus[path] = status
      if fileinfo.kind == "input" then
        status.mtime = status.mtime or filesys.attributes(path, "modification")
      elseif fileinfo.kind == "auxiliary" then
        status.size = status.size or filesys.attributes(path, "size")
        status.md5sum = status.md5sum or md5sum_file(path)
      end
    end
  end
  return auxstatus
end

-- should_rerun, newauxstatus = comparefileinfo(auxfiles, auxstatus)
local function comparefileinfo(filelist, auxstatus)
  local should_rerun = false
  local newauxstatus = {}
  for i,fileinfo in ipairs(filelist) do
    local path = fileinfo.abspath
    if fsutil.isfile(path) then
      if fileinfo.kind == "input" then
        -- Input file: User might have modified while running TeX.
        local mtime = filesys.attributes(path, "modification")
        if auxstatus[path] and auxstatus[path].mtime then
          if auxstatus[path].mtime < mtime then
            -- Input file was updated during execution
            if CLUTTEX_VERBOSITY >= 1 then
              io.stderr:write("cluttex: File '", fileinfo.path, "' was modified by user.\n")
            end
            newauxstatus[path] = {mtime = mtime}
            return true, newauxstatus
          end
        else
          -- New input file
        end

      elseif fileinfo.kind == "auxiliary" then
        -- Auxiliary file: Compare file contents.
        if auxstatus[path] then
          -- File was touched during execution
          local really_modified = false
          local size = filesys.attributes(path, "size")
          if auxstatus[path].size ~= size then
            really_modified = true
            newauxstatus[path] = {size = size}
          else
            local md5sum = md5sum_file(path)
            if auxstatus[path].md5sum ~= md5sum then
              really_modified = true
            end
            newauxstatus[path] = {size = size, md5sum = md5sum}
          end
          if really_modified then
            if CLUTTEX_VERBOSITY >= 1 then
              io.stderr:write("cluttex: File '", fileinfo.path, "' was modified.\n")
            end
            should_rerun = true
          else
            if CLUTTEX_VERBOSITY >= 1 then
              io.stderr:write("cluttex: File '", fileinfo.path, "' unmodified (size and md5sum).\n")
            end
          end
        else
          -- New file
          if path:sub(-4) == ".aux" then
            local size = filesys.attributes(path, "size")
            if size == 8 then
              local auxfile = io.open(path, "rb")
              local contents = auxfile:read("*a")
              auxfile:close()
              if contents == "\\relax \n" then
                -- The .aux file is new, but it is almost empty
              else
                should_rerun = true
              end
              newauxstatus[path] = {size = size, md5sum = md5.sum(contents)}
            else
              should_rerun = true
              newauxstatus[path] = {size = size}
            end
          else
            should_rerun = true
          end
          if CLUTTEX_VERBOSITY >= 1 then
            if should_rerun then
              io.stderr:write("cluttex: New input file '", fileinfo.path, "'.\n")
            else
              io.stderr:write("cluttex: New input file '", fileinfo.path, "'. (not modified)\n")
            end
          end
        end
        if should_rerun then
          break
        end
      end
    else
      -- Auxiliary file is not really a file???
    end
  end
  return should_rerun, newauxstatus
end

return {
  parse_recorder_file = parse_recorder_file;
  collectfileinfo = collectfileinfo;
  comparefileinfo = comparefileinfo;
}
