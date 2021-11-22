local function create_initialization_script(filename, options)
  local initscript = assert(io.open(filename,"w"))
  if type(options.file_line_error) == "boolean" then
    initscript:write(string.format("texconfig.file_line_error = %s\n", options.file_line_error))
  end
  if type(options.halt_on_error) == "boolean" then
    initscript:write(string.format("texconfig.halt_on_error = %s\n", options.halt_on_error))
  end
  initscript:write([==[
local print = print
local io_open = io.open
local io_write = io.write
local os_execute = os.execute
local texio_write = texio.write
local texio_write_nl = texio.write_nl
]==])

  -- Packages coded in Lua doesn't follow -output-directory option and doesn't write command to the log file
  initscript:write(string.format("local output_directory = %q\n", options.output_directory))
  -- tex.jobname may not be available when io.open is called for the first time
  initscript:write(string.format("local jobname = %q\n", options.jobname))
  initscript:write([==[
local luawritelog
local function openluawritelog()
  if not luawritelog then
    luawritelog = assert(io_open(output_directory .. "/" .. jobname .. ".cluttex-fls", "w"))
  end
  return luawritelog
end
io.open = function(fname, mode)
  -- luatexja-ruby
  if mode == "w" and fname == jobname .. ".ltjruby" then
    fname = output_directory .. "/" .. fname
  end
  if type(mode) == "string" and string.find(mode, "w") ~= nil then
    -- write mode
    openluawritelog():write("OUTPUT " .. fname .. "\n")
  end
  return io_open(fname, mode)
end
os.execute = function(...)
  texio_write_nl("log", string.format("CLUTTEX_EXEC %s", ...), "")
  return os_execute(...)
end
]==])

  -- Silence some of the TeX output to the terminal.
  initscript:write([==[
local function start_file_cb(category, filename)
  if category == 1 then -- a normal data file, like a TeX source
    texio_write_nl("log", "("..filename)
  elseif category == 2 then -- a font map coupling font names to resources
    texio_write("log", "{"..filename)
  elseif category == 3 then -- an image file (png, pdf, etc)
    texio_write("<"..filename)
  elseif category == 4 then -- an embedded font subset
    texio_write("<"..filename)
  elseif category == 5 then -- a fully embedded font
    texio_write("<<"..filename)
  else
    print("start_file: unknown category", category, filename)
  end
end
callback.register("start_file", start_file_cb)
local function stop_file_cb(category)
  if category == 1 then
    texio_write("log", ")")
  elseif category == 2 then
    texio_write("log", "}")
  elseif category == 3 then
    texio_write(">")
  elseif category == 4 then
    texio_write(">")
  elseif category == 5 then
    texio_write(">>")
  else
    print("stop_file: unknown category", category)
  end
end
callback.register("stop_file", stop_file_cb)
texio.write = function(...)
  if select("#",...) == 1 then
    -- Suppress luaotfload's message (See src/fontloader/runtime/fontload-reference.lua)
    local s = ...
    if string.match(s, "^%(using cache: ")
       or string.match(s, "^%(using write cache: ")
       or string.match(s, "^%(using read cache: ")
       or string.match(s, "^%(load luc: ")
       or string.match(s, "^%(load cache: ") then
      return texio_write("log", ...)
    end
  end
  return texio_write(...)
end
]==])

  -- Fix "arg" to make luamplib work
  initscript:write([==[
if string.match(arg[0], "^%-%-lua=") then
  local minindex = 0
  while arg[minindex - 1] ~= nil do
    minindex = minindex - 1
  end
  local arg2 = {}
  for i = 0, #arg - minindex do
    arg2[i] = arg[i + minindex]
  end
  arg = arg2
end
]==])
  initscript:close()
end

return {
  create_initialization_script = create_initialization_script
}
