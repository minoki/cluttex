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

--[[
  This module provides:
    pathutil.basename(path)
    pathutil.dirname(path)
    pathutil.trimext(path)
    pathutil.ext(path)
    pathutil.replaceext(path, newext)
    pathutil.join(...)
  pathutil.abspath(path [, cwd])
]]

if os.type == "windows" then
  return require("texrunner.pathutil_windows")
else
  return require("texrunner.pathutil_unix")
end
