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

local string_match = string.match
local pathutil = require "texrunner.pathutil"
local filesys = require "lfs"
local fsutil = require "texrunner.fsutil"

-- for LaTeX
local function parse_aux_file(auxfile, outdir, report, seen)
  report = report or {}
  seen = seen or {}
  seen[auxfile] = true
  for l in io.lines(auxfile) do
    local subauxfile = string_match(l, "\\@input{(.+)}")
    if subauxfile then
      if fsutil.isfile(subauxfile) then
        parse_aux_file(pathutil.join(outdir, subauxfile), outdir, report, seen)
      else
        local dir = pathutil.join(outdir, pathutil.dirname(subauxfile))
        if not fsutil.isdir(dir) then
          assert(fsutil.mkdir_rec(dir))
          report.made_new_directory = true
        end
      end
    end
  end
  return report
end

return {
  parse_aux_file = parse_aux_file,
}
