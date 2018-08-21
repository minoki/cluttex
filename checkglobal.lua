if #arg == 0 then
  io.stderr:write[[
Usage: lua checkglobal.lua <file.lua>
]]
  os.exit(1)
end
local f = assert(io.popen("luac -l -l " .. arg[1]))
local known_global = {
  -- Basic
  _G = true,
  _VERSION = true,
  assert = true,
  collectgarbage = true,
  dofile = true,
  error = true,
  getmetatable = true,
  ipairs = true,
  load = true,
  loadfile = true,
  next = true,
  pairs = true,
  pcall = true,
  print = true,
  rawequal = true,
  rawget = true,
  rawlen = true,
  rawset = true,
  require = true,
  select = true,
  setmetatable = true,
  tonumber = true,
  tostring = true,
  type = true,
  xpcall = true,

  -- Standard modules
  bit32 = true, -- Lua 5.2
  coroutine = true,
  debug = true,
  io = true,
  math = true,
  os = true,
  package = true,
  string = true,
  table = true,
  -- Lua 5.3 adds 'utf8' module

  -- LuaJIT / LuaTeX extensions
  bit = true,
  lfs = true,

  -- Others
  arg = true, -- command line argument
}
local result = true
for line in f:lines() do
  local m = line:match("; _ENV \"(%w+)\"")
  if m then
    if not known_global[m] then
      print("Unknown global variable: ", m)
      result = false
    end
  end
end
if result then
  os.exit(0)
else
  os.exit(1)
end
