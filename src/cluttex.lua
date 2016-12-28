#!/usr/bin/env texlua
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
local parseoption = require "texrunner.option".parseoption
local parse_aux_file = require "texrunner.auxfile".parse_aux_file
local KnownEngines = require "texrunner.tex_engine"

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

local COPYRIGHT_NOTICE = [[
Copyright (C) 2016  ARATA Mizuki

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local function usage()
  io.write(string.format([[
ClutTeX: Process TeX files without cluttering your working directory

Usage:
  %s [options] [--] FILE.tex

Options:
  -e, --engine=ENGINE          Specify which TeX engine to use.
                                 ENGINE is one of the following:
                                     pdflatex, pdftex, lualatex, luatex,
                                     xelatex, xetex, latex, etex, tex,
                                     platex, eptex, ptex,
                                     uplatex, euptex, uptex,
  -o, --output=FILE            The name of output file.
                                 [default: JOBNAME.pdf or JOBNAME.dvi]
      --fresh                  Clean intermediate files before running TeX.
                                 Cannot be used with --output-directory.
      --max-iterations=N       Maximum number of re-running TeX to resolve
                                 cross-references.  [default: 5]
      --[no-]change-directory  Change directory before running TeX.
      --watch                  Watch input files for change.  Requires fswatch
                                 program to be installed.
      --tex-option=OPTION      Pass OPTION to TeX as a single option.
      --tex-options=OPTIONs    Pass OPTIONs to TeX as multiple options.
      --dvipdfmx-option[s]=OPTION[s]  Same for dvipdfmx.
  -h, --help                   Print this message and exit.
  -v, --version                Print version information and exit.
  -V, --verbose                Be more verbose.

      --[no-]shell-escape
      --shell-restricted
      --synctex=NUMBER
      --[no-]file-line-error   [default: yes]
      --[no-]halt-on-error     [default: yes]
      --interaction=STRING     [default: nonstopmode]
      --jobname=STRING
      --output-directory=DIR   [default: somewhere in the temporary directory]
      --output-format=FORMAT   FORMAT is `pdf' or `dvi'.  [default: pdf]

%s
]], arg[0] or 'texlua cluttex.lua', COPYRIGHT_NOTICE))
end

-- Parse options
local option_and_params, non_option_index = parseoption(arg, {
  -- Options for this script
  {
    short = "e",
    long = "engine",
    param = true,
  },
  {
    short = "o",
    long = "output",
    param = true,
  },
  {
    long = "fresh",
  },
  {
    long = "max-iterations",
    param = true,
  },
  {
    long = "change-directory",
    boolean = true,
  },
  {
    long = "watch",
  },
  {
    short = "h",
    long = "help",
  },
  {
    short = "v",
    long = "version",
  },
  {
    short = "V",
    long = "verbose",
  },
  -- Options for TeX
  {
    long = "synctex",
    param = true,
  },
  {
    long = "file-line-error",
    boolean = true,
  },
  {
    long = "interaction",
    param = true,
  },
  {
    long = "halt-on-error",
    boolean = true,
  },
  {
    long = "shell-escape",
    boolean = true,
  },
  {
    long = "shell-restricted",
  },
  {
    long = "jobname",
    param = true,
  },
  {
    long = "output-directory",
    param = true,
  },
  {
    long = "output-format",
    param = true,
  },
  {
    long = "tex-option",
    param = true,
  },
  {
    long = "tex-options",
    param = true,
  },
  {
    long = "dvipdfmx-option",
    param = true,
  },
  {
    long = "dvipdfmx-options",
    param = true,
  },
})

-- Handle options
local options = {}
local tex_extraoptions = {}
local dvipdfmx_extraoptions = {}
CLUTTEX_VERBOSITY = 0
for _,option in ipairs(option_and_params) do
  local name = option[1]
  local param = option[2]

  if name == "engine" then
    assert(options.engine == nil, "multiple --engine options")
    options.engine = param

  elseif name == "output" then
    assert(options.output == nil, "multiple --output options")
    options.output = param

  elseif name == "fresh" then
    assert(options.fresh == nil, "multiple --fresh options")
    options.fresh = true

  elseif name == "max-iterations" then
    assert(options.max_iterations == nil, "multiple --max-iterations options")
    options.max_iterations = assert(tonumber(param), "invalid value for --max-iterations option")

  elseif name == "watch" then
    assert(options.watch == nil, "multiple --watch options")
    options.watch = true

  elseif name == "help" then
    usage()
    os.exit(0)

  elseif name == "version" then
    io.stderr:write("cluttex (prerelease)\n")
    os.exit(0)

  elseif name == "verbose" then
    CLUTTEX_VERBOSITY = CLUTTEX_VERBOSITY + 1

  elseif name == "change-directory" then
    assert(options.change_directory == nil, "multiple --change-directory options")
    options.change_directory = param

  -- Options for TeX
  elseif name == "synctex" then
    assert(options.synctex == nil, "multiple --synctex options")
    options.synctex = param

  elseif name == "file-line-error" then
    options.file_line_error = param

  elseif name == "interaction" then
    assert(options.interaction == nil, "multiple --interaction options")
    assert(param == "batchmode" or param == "nonstopmode" or param == "scrollmode" or param == "errorstopmode", "invalid argument for --interaction")
    options.interaction = param

  elseif name == "halt-on-error" then
    options.halt_on_error = param

  elseif name == "shell-escape" then
    assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
    options.shell_escape = param

  elseif name == "shell-restricted" then
    assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
    options.shell_restricted = true

  elseif name == "jobname" then
    assert(options.jobname == nil, "multiple --jobname options")
    options.jobname = param

  elseif name == "output-directory" then
    assert(options.output_directory == nil, "multiple --output-directory options")
    options.output_directory = param

  elseif name == "output-format" then
    assert(options.output_format == nil, "multiple --output-format options")
    assert(param == "pdf" or param == "dvi", "invalid argument for --output-format")
    options.output_format = param

  elseif name == "tex-option" then
    table.insert(tex_extraoptions, shellutil.escape(param))

  elseif name == "tex-options" then
    table.insert(tex_extraoptions, param)

  elseif name == "dvipdfmx-option" then
    table.insert(dvipdfmx_extraoptions, shellutil.escape(param))

  elseif name == "dvipdfmx-options" then
    table.insert(dvipdfmx_extraoptions, param)

  end
end

-- Handle non-options (i.e. input file)
if non_option_index > #arg then
  -- No input file given
  usage()
  os.exit(1)
elseif non_option_index < #arg then
  io.stderr("cluttex: Multiple input files are not supported.\n")
  os.exit(1)
end
local inputfile = arg[non_option_index]

if options.engine == nil then
  io.stderr:write("cluttex: Engine not specified.\n")
  os.exit(1)
end
local engine = KnownEngines[options.engine]
if not engine then
  io.stderr:write("cluttex: Unknown engine name '", options.engine, "'.\n")
  os.exit(1)
end

-- Default values for options
if options.max_iterations == nil then
  options.max_iterations = 5
end

if options.interaction == nil then
  options.interaction = "nonstopmode"
end

if options.file_line_error == nil then
  options.file_line_error = true
end

if options.halt_on_error == nil then
  options.halt_on_error = true
end

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
      io.stderr:write("cluttex: Cleaning '", options.output_directory, "'...\n")
    end
    assert(fsutil.remove_rec(options.output_directory))
    assert(filesys.mkdir(options.output_directory))
  end

elseif options.fresh then
  io.stderr:write("cluttex: --fresh and --output-directory cannot be used together.\n")
  os.exit(1)
end

local original_wd = filesys.currentdir()
if options.change_directory then
  local TEXINPUTS = os.getenv("TEXINPUTS") or ""
  filesys.chdir(options.output_directory)
  options.output = pathutil.abspath(options.output, original_wd)
  os.setenv("TEXINPUTS", original_wd .. ":" .. TEXINPUTS)
end

-- Set `max_print_line' environment variable if not already set.
if os.getenv("max_print_line") == nil then
  os.setenv("max_print_line", "2048")
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
  extraoptions = tex_extraoptions,
}
if options.output_format ~= "pdf" and engine.supports_pdf_generation then
  tex_options.output_format = options.output_format
end
local command = engine:build_command(inputfile, tex_options)

local function create_missing_directories()
  -- Check log file
  local logfile = assert(io.open(path_in_output_directory("log")))
  local execlog = logfile:read("*a")
  logfile:close()
  if string.find(execlog, "I can't write on file", 1, true) then
    -- There is a possibility that there are some subfiles under subdirectories.
    -- Directories for sub-auxfiles are not created automatically, so we need to provide them.
    local report = parse_aux_file(path_in_output_directory("aux"), options.output_directory)
    if report.made_new_directory then
      if CLUTTEX_VERBOSITY >= 1 then
        io.stderr:write("cluttex: Created missing directories.\n")
      end
      return true
    end
  end
  return false
end

-- Run TeX command (*tex, *latex)
-- should_rerun, newauxstatus = single_run([auxstatus])
local function single_run(auxstatus)
  if fsutil.isfile(recorderfile) then
    -- Recorder file already exists
    local filelist = reruncheck.parse_recorder_file(recorderfile)
    auxstatus = reruncheck.collectfileinfo(filelist, auxstatus)
  else
    -- This is the first execution
    if auxstatus ~= nil then
      io.stderr:write("cluttex: Recorder file was not generated during the execution!\n")
      os.exit(1)
    end
    auxstatus = {}
  end
  --local timestamp = os.time()

  local recovered = false
  local function recover()
    if create_missing_directories() then
      recovered = true
      return true
    else
      return false
    end
  end
  coroutine.yield(command, recover) -- Execute the command
  if recovered then
    return true, {}
  end

  local filelist = reruncheck.parse_recorder_file(recorderfile)
  return reruncheck.comparefileinfo(filelist, auxstatus)
end

-- Run (La)TeX (possibly multiple times) and produce a PDF file.
-- This function should be run in a coroutine.
local function do_typeset_c()
  local iteration = 0
  local should_rerun, auxstatus
  repeat
    iteration = iteration + 1
    should_rerun, auxstatus = single_run(auxstatus)
  until not should_rerun or iteration > options.max_iterations

  if should_rerun then
    io.stderr:write("cluttex warning: LaTeX should be run once more.\n")
  end

  -- Successful
  if options.output_format == "dvi" or engine.supports_pdf_generation then
    -- Output file (DVI/PDF) is generated in the output directory
    local outfile = path_in_output_directory(output_extension)
    coroutine.yield(fsutil.copy_command(outfile, options.output))
    if #dvipdfmx_extraoptions > 0 then
      io.stderr:write("cluttex warning: --dvipdfmx-option[s] are ignored.\n")
    end

  else
    -- DVI file is generated
    local dvifile = path_in_output_directory("dvi")
    local dvipdfmx_command = {"dvipdfmx", "-o", shellutil.escape(options.output)}
    for _,v in ipairs(dvipdfmx_extraoptions) do
      table.insert(dvipdfmx_command, v)
    end
    table.insert(dvipdfmx_command, shellutil.escape(dvifile))
    coroutine.yield(table.concat(dvipdfmx_command, " "))
  end
end

local function do_typeset()
  -- Execute the command string yielded by do_typeset_c
  for command, recover in coroutine.wrap(do_typeset_c) do
    io.stderr:write("EXEC ", command, "\n")
    local success, termination, status_or_signal = os.execute(command)
    if type(success) == "number" then -- Lua 5.1 or LuaTeX
      local code = success
      success = code == 0
      termination = nil
      status_or_signal = code
    end
    if not success and not (recover and recover()) then
      if termination == "exit" then
        io.stderr:write("cluttex: Command exited abnormally: exit status ", tostring(status_or_signal), "\n")
      elseif termination == "signal" then
        io.stderr:write("cluttex: Command exited abnormally: signal ", tostring(status_or_signal), "\n")
      else
        io.stderr:write("cluttex: Command exited abnormally: ", tostring(status_or_signal), "\n")
      end
      return false, termination, status_or_signal
    end
  end
  -- Successful
  if CLUTTEX_VERBOSITY >= 1 then
    io.stderr:write("cluttex: Command exited successfully\n")
  end
  return true
end

if options.watch then
  -- Watch mode
  local success, status = do_typeset()
  local filelist = reruncheck.parse_recorder_file(recorderfile)
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
    io.stderr:write("EXEC ", table.concat(fswatch_command, " "), "\n")
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
