#!/usr/bin/env texlua
--[[
  Copyright 2016,2018 ARATA Mizuki

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

-- Standard libraries
local table = table
local os = os
local io = io
local string = string
local ipairs = ipairs
local coroutine = coroutine
local tostring = tostring

-- External libraries (included in texlua)
local filesys = require "lfs"
local md5     = require "md5"
-- local kpse = require "kpse"

-- My own modules
local pathutil    = require "texrunner.pathutil"
local fsutil      = require "texrunner.fsutil"
local shellutil   = require "texrunner.shellutil"
local reruncheck  = require "texrunner.reruncheck"
local luatexinit  = require "texrunner.luatexinit"
local recoverylib = require "texrunner.recovery"
local message     = require "texrunner.message"
local extract_bibtex_from_aux_file = require "texrunner.auxfile".extract_bibtex_from_aux_file
local handle_cluttex_options = require "texrunner.handleoption".handle_cluttex_options

-- arguments: input file name, jobname, etc...
local function genOutputDirectory(...)
  -- The name of the temporary directory is based on the path of input file.
  local message = table.concat({...}, "\0")
  local hash = md5.sumhexa(message)
  local tmpdir = os.getenv("TMPDIR") or os.getenv("TMP") or os.getenv("TEMP")
  if tmpdir == nil then
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or error("environment variable 'TMPDIR' not set!")
    tmpdir = pathutil.join(home, ".latex-build-temp")
  end
  return pathutil.join(tmpdir, 'latex-build-' .. hash)
end

local inputfile, engine, options = handle_cluttex_options(arg)

local jobname = options.jobname or pathutil.basename(pathutil.trimext(inputfile))
assert(jobname ~= "", "jobname cannot be empty")

if options.output_format == nil then
  options.output_format = "pdf"
end
local output_extension
if options.output_format == "dvi" then
  output_extension = engine.dvi_extension or "dvi"
else
  output_extension = "pdf"
end

if options.output == nil then
  options.output = jobname .. "." .. output_extension
end

-- Prepare output directory
if options.output_directory == nil then
  local inputfile_abs = pathutil.abspath(inputfile)
  options.output_directory = genOutputDirectory(inputfile_abs, jobname, options.engine)

  if not fsutil.isdir(options.output_directory) then
    assert(fsutil.mkdir_rec(options.output_directory))

  elseif options.fresh then
    -- The output directory exists and --fresh is given:
    -- Remove all files in the output directory
    if CLUTTEX_VERBOSITY >= 1 then
      message.info("Cleaning '", options.output_directory, "'...")
    end
    assert(fsutil.remove_rec(options.output_directory))
    assert(filesys.mkdir(options.output_directory))
  end

elseif options.fresh then
  message.error("--fresh and --output-directory cannot be used together.")
  os.exit(1)
end

local original_wd = filesys.currentdir()
if options.change_directory then
  local TEXINPUTS = os.getenv("TEXINPUTS") or ""
  filesys.chdir(options.output_directory)
  options.output = pathutil.abspath(options.output, original_wd)
  os.setenv("TEXINPUTS", original_wd .. ":" .. TEXINPUTS)
end
if options.bibtex then
  local BIBINPUTS = os.getenv("BIBINPUTS") or ""
  options.output = pathutil.abspath(options.output, original_wd)
  os.setenv("BIBINPUTS", original_wd .. ":" .. BIBINPUTS)
end

-- Set `max_print_line' environment variable if not already set.
if os.getenv("max_print_line") == nil then
  os.setenv("max_print_line", "65536")
end
-- TODO: error_line, half_error_line
--[[
  According to texmf.cnf:
    45 < error_line < 255,
    30 < half_error_line < error_line - 15,
    60 <= max_print_line.
]]

local function path_in_output_directory(ext)
  return pathutil.join(options.output_directory, jobname .. "." .. ext)
end

local recorderfile = path_in_output_directory("fls")

local tex_options = {
  interaction = options.interaction,
  file_line_error = options.file_line_error,
  halt_on_error = options.halt_on_error,
  synctex = options.synctex,
  output_directory = options.output_directory,
  shell_escape = options.shell_escape,
  shell_restricted = options.shell_restricted,
  jobname = options.jobname,
  fmt = options.fmt,
  extraoptions = options.tex_extraoptions,
}
if options.output_format ~= "pdf" and engine.supports_pdf_generation then
  tex_options.output_format = options.output_format
end

-- Setup LuaTeX initialization script
if engine.is_luatex then
  local initscriptfile = path_in_output_directory("cluttexinit.lua")
  luatexinit.create_initialization_script(initscriptfile, tex_options)
  tex_options.lua_initialization_script = initscriptfile
end

-- Run TeX command (*tex, *latex)
-- should_rerun, newauxstatus = single_run([auxstatus])
-- This function should be run in a coroutine.
local function single_run(auxstatus, iteration)
  local minted = false
  local bibtex_aux_hash = nil
  local mainauxfile = path_in_output_directory("aux")
  if fsutil.isfile(recorderfile) then
    -- Recorder file already exists
    local filelist = reruncheck.parse_recorder_file(recorderfile, options)
    auxstatus = reruncheck.collectfileinfo(filelist, auxstatus)
    for _,fileinfo in ipairs(filelist) do
      if string.match(fileinfo.path, "minted/minted%.sty$") then
        minted = true
        break
      end
    end
    if options.bibtex then
      local biblines = extract_bibtex_from_aux_file(mainauxfile, options.output_directory)
      if #biblines > 0 then
        bibtex_aux_hash = md5.sum(table.concat(biblines, "\n"))
      end
    end
  else
    -- This is the first execution
    if auxstatus ~= nil then
      message.error("Recorder file was not generated during the execution!")
      os.exit(1)
    end
    auxstatus = {}
  end
  --local timestamp = os.time()

  if options.includeonly then
    tex_options.tex_injection = string.format("%s\\includeonly{%s}", tex_options.tex_injection or "", options.includeonly)
  end

  if minted and not (tex_options.tex_injection and string.find(tex_options.tex_injection,"minted") == nil) then
    tex_options.tex_injection = string.format("%s\\PassOptionsToPackage{outputdir=%s}{minted}", tex_options.tex_injection or "", options.output_directory)
  end

  local current_tex_options, lightweight_mode = tex_options, false
  if iteration == 1 and options.start_with_draft then
    current_tex_options = {}
    for k,v in pairs(tex_options) do
      current_tex_options[k] = v
    end
    if engine.supports_draftmode then
      current_tex_options.draftmode = true
      options.start_with_draft = false
    end
    current_tex_options.interaction = "batchmode"
    lightweight_mode = true
  else
    current_tex_options.draftmode = false
  end

  local command = engine:build_command(inputfile, current_tex_options)

  local execlog -- the contents of .log file

  local recovered = false
  local function recover()
    -- Check log file
    if not execlog then
      local logfile = assert(io.open(path_in_output_directory("log")))
      execlog = logfile:read("*a")
      logfile:close()
    end
    recovered = recoverylib.try_recovery{
      execlog = execlog,
      auxfile = path_in_output_directory("aux"),
      options = options,
      original_wd = original_wd,
    }
    return recovered
  end
  coroutine.yield(command, recover) -- Execute the command
  if recovered then
    return true, {}
  end

  local filelist = reruncheck.parse_recorder_file(recorderfile, options)

  if options.makeindex then
    -- Look for .idx files and run MakeIndex
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "idx" then
        -- Run makeindex if the .idx file is new or updated
        local idxfileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        if reruncheck.comparefileinfo({idxfileinfo}, auxstatus) then
          local output_ind = pathutil.replaceext(file.abspath, "ind")
          local idx_dir = pathutil.dirname(file.abspath)
          local makeindex_command = {
            "cd", shellutil.escape(idx_dir), "&&",
            options.makeindex, -- Do not escape options.makeindex to allow additional options
            "-o", pathutil.basename(output_ind),
            pathutil.basename(file.abspath)
          }
          coroutine.yield(table.concat(makeindex_command, " "))
          table.insert(filelist, {path = output_ind, abspath = output_ind, kind = "auxiliary"})
        end
      end
    end
  else
    -- Check log file
    if not execlog then
      local logfile = assert(io.open(path_in_output_directory("log")))
      execlog = logfile:read("*a")
      logfile:close()
    end
    if string.find(execlog, "No file [^\n]+%.ind%.") then
      message.diag("You may want to use --makeindex option.")
    end
  end

  if options.makeglossaries then
    -- Look for .glo files and run makeglossaries
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "glo" then
        -- Run makeglossaries if the .glo file is new or updated
        local glofileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        if reruncheck.comparefileinfo({glofileinfo}, auxstatus) then -- TODO: Check if .gls file exists
          local output_gls = pathutil.replaceext(file.abspath, "gls")
          local makeglossaries_command = {
            options.makeglossaries,
            "-d", shellutil.escape(options.output_directory),
            pathutil.trimext(pathutil.basename(file.path))
          }
          coroutine.yield(table.concat(makeglossaries_command, " "))
          table.insert(filelist, {path = output_gls, abspath = output_gls, kind = "auxiliary"})
        end
      end
    end
  else
    -- Check log file
    if not execlog then
      local logfile = assert(io.open(path_in_output_directory("log")))
      execlog = logfile:read("*a")
      logfile:close()
    end
    if string.find(execlog, "No file [^\n]+%.gls%.") then
      message.diag("You may want to use --makeglossaries option.")
    end
  end

  if options.bibtex then
    local biblines2 = extract_bibtex_from_aux_file(mainauxfile, options.output_directory)
    local bibtex_aux_hash2
    if #biblines2 > 0 then
      bibtex_aux_hash2 = md5.sum(table.concat(biblines2, "\n"))
    end
    if bibtex_aux_hash ~= bibtex_aux_hash2 then
      -- The input for BibTeX command has changed...
      local bibtex_command = {
        "cd", shellutil.escape(options.output_directory), "&&",
        options.bibtex,
        pathutil.basename(mainauxfile)
      }
      coroutine.yield(table.concat(bibtex_command, " "))
    else
      if CLUTTEX_VERBOSITY >= 1 then
        message.info("No need to run BibTeX.")
      end
    end
  elseif options.biber then
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "bcf" then
        -- Run biber if the .bcf file is new or updated
        local bcffileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        if reruncheck.comparefileinfo({bcffileinfo}, auxstatus) then
          local output_bbl = pathutil.replaceext(file.abspath, "bbl")
          local bbl_dir = pathutil.dirname(file.abspath)
          local biber_command = {
            options.biber, -- Do not escape options.biber to allow additional options
            "--output-directory", shellutil.escape(options.output_directory),
            pathutil.basename(file.abspath)
          }
          coroutine.yield(table.concat(biber_command, " "))
          table.insert(filelist, {path = output_bbl, abspath = output_bbl, kind = "auxiliary"})
        end
      end
    end
  else
    -- Check log file
    if not execlog then
      local logfile = assert(io.open(path_in_output_directory("log")))
      execlog = logfile:read("*a")
      logfile:close()
    end
    if string.find(execlog, "No file [^\n]+%.bbl%.") then
      message.diag("You may want to use --bibtex or --biber option.")
    end
  end

  local should_rerun, auxstatus = reruncheck.comparefileinfo(filelist, auxstatus)
  return should_rerun or lightweight_mode, auxstatus
end

-- Run (La)TeX (possibly multiple times) and produce a PDF file.
-- This function should be run in a coroutine.
local function do_typeset_c()
  local iteration = 0
  local should_rerun, auxstatus
  repeat
    iteration = iteration + 1
    should_rerun, auxstatus = single_run(auxstatus, iteration)
  until not should_rerun or iteration >= options.max_iterations

  if should_rerun then
    message.warn("LaTeX should be run once more.")
  end

  -- Successful
  if options.output_format == "dvi" or engine.supports_pdf_generation then
    -- Output file (DVI/PDF) is generated in the output directory
    local outfile = path_in_output_directory(output_extension)
    local oncopyerror
    if os.type == "windows" then
      oncopyerror = function()
        message.error("Failed to copy file.  Some applications may be locking the ", string.upper(options.output_format), " file.")
        return false
      end
    end
    coroutine.yield(fsutil.copy_command(outfile, options.output), oncopyerror)
    if #options.dvipdfmx_extraoptions > 0 then
      message.warn("--dvipdfmx-option[s] are ignored.")
    end

  else
    -- DVI file is generated, but PDF file is wanted
    local dvifile = path_in_output_directory("dvi")
    local dvipdfmx_command = {"dvipdfmx", "-o", shellutil.escape(options.output)}
    for _,v in ipairs(options.dvipdfmx_extraoptions) do
      table.insert(dvipdfmx_command, v)
    end
    table.insert(dvipdfmx_command, shellutil.escape(dvifile))
    coroutine.yield(table.concat(dvipdfmx_command, " "))
  end

  -- Copy SyncTeX file if necessary
  if options.output_format == "pdf" then
    local synctex = tonumber(options.synctex or "0")
    local synctex_ext = nil
    if synctex > 0 then
      -- Compressed SyncTeX file (.synctex.gz)
      synctex_ext = "synctex.gz"
    elseif synctex < 0 then
      -- Uncompressed SyncTeX file (.synctex)
      synctex_ext = "synctex"
    end
    if synctex_ext then
      coroutine.yield(fsutil.copy_command(path_in_output_directory(synctex_ext), pathutil.replaceext(options.output, synctex_ext)))
    end
  end
end

local function do_typeset()
  -- Execute the command string yielded by do_typeset_c
  for command, recover in coroutine.wrap(do_typeset_c) do
    message.exec(command)
    local success, termination, status_or_signal = os.execute(command)
    if type(success) == "number" then -- Lua 5.1 or LuaTeX
      local code = success
      success = code == 0
      termination = nil
      status_or_signal = code
    end
    if not success and not (recover and recover()) then
      if termination == "exit" then
        message.error("Command exited abnormally: exit status ", tostring(status_or_signal))
      elseif termination == "signal" then
        message.error("Command exited abnormally: signal ", tostring(status_or_signal))
      else
        message.error("Command exited abnormally: ", tostring(status_or_signal))
      end
      return false, termination, status_or_signal
    end
  end
  -- Successful
  if CLUTTEX_VERBOSITY >= 1 then
    message.info("Command exited successfully")
  end
  return true
end

if options.watch then
  -- Watch mode
  local success, status = do_typeset()
  local filelist = reruncheck.parse_recorder_file(recorderfile, options)
  local input_files_to_watch = {}
  for _,fileinfo in ipairs(filelist) do
    if fileinfo.kind == "input" then
      table.insert(input_files_to_watch, fileinfo.abspath)
    end
  end
  local fswatch_command = {"fswatch", "--event=Updated", "--"}
  for _,path in ipairs(input_files_to_watch) do
    table.insert(fswatch_command, shellutil.escape(path))
  end
  if CLUTTEX_VERBOSITY >= 1 then
    message.exec(table.concat(fswatch_command, " "))
  end
  local fswatch = assert(io.popen(table.concat(fswatch_command, " "), "r"))
  for l in fswatch:lines() do
    local found = false
    for _,path in ipairs(input_files_to_watch) do
      if l == path then
        found = true
        break
      end
    end
    if found then
      local success, status = do_typeset()
      if not success then
        -- Not successful
      end
    end
  end

else
  -- Not in watch mode
  local success, status = do_typeset()
  if not success then
    os.exit(1)
  end
end
