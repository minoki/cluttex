local assert = assert
local ipairs = ipairs
local error = error
local string = string
local pathutil = require "texrunner.pathutil"
local message = require "texrunner.message"

local right_values = {
  dvips = {
    graphics = "dvips",
    expl3    = "dvips",
    hyperref = "dvips",
    xypic    = "dvips",
  },
  dvipdfmx = {
    graphics = "dvipdfmx",
    expl3    = "dvipdfmx",
    hyperref = "dvipdfmx",
    xypic    = "pdf",
  },
  dvisvgm = {
    graphics = "dvisvgm",
    expl3    = "dvisvgm",
  },
  xetex = {
    graphics = "xetex",
    expl3    = "xdvipdfmx",
    hyperref = "xetex",
    xypic    = "pdf",
  },
  pdftex = {
    graphics = "pdftex",
    expl3    = "pdfmode",
    hyperref = "pdftex",
    xypic    = "pdf",
  },
  luatex = {
    graphics = "luatex",
    expl3    = "pdfmode",
    hyperref = "luatex",
    xypic    = "pdf",
  },
}

-- expected_driver: one of "dvips", "dvipdfmx", "dvisvgm", "pdftex", "xetex", "luatex"
local function checkdriver(expected_driver, filelist)
  if CLUTTEX_VERBOSITY >= 1 then
    message.info("checkdriver: expects ", expected_driver)
  end

  local loaded = {}
  for i,t in ipairs(filelist) do
    if t.kind == "input" then
      local basename = pathutil.basename(t.path)
      loaded[basename] = true
    end
  end

  local graphics_driver = nil -- "dvipdfmx" | "dvips" | "dvisvgm" | "pdftex" | "luatex" | "xetex" | "unknown"
  if loaded["graphics.sty"] or loaded["color.sty"] then
    if loaded["dvipdfmx.def"] then
      graphics_driver = "dvipdfmx"
    elseif loaded["dvips.def"] then
      graphics_driver = "dvips"
    elseif loaded["dvisvgm.def"] then
      graphics_driver = "dvisvgm"
    elseif loaded["pdftex.def"] then
      graphics_driver = "pdftex"
    elseif loaded["luatex.def"] then
      graphics_driver = "luatex"
    elseif loaded["xetex.def"] then
      graphics_driver = "xetex"
    else
      -- Not supported: dvipdf, dvipsone, emtex, textures, pctexps, pctexwin, pctexhp, pctex32, truetex, tcidvi, vtex
      graphics_driver = "unknown"
    end
  end
  local expl3_driver = nil -- "pdfmode" | "dvisvgm" | "xdvipdfmx" | "dvipdfmx" | "dvips" | "unknown"
  if loaded["expl3-code.tex"] or loaded["expl3.sty"] or loaded["l3backend-dvips.def"] or loaded["l3backend-dvipdfmx.def"] or loaded["l3backend-xdvipdfmx.def"] or loaded["l3backend-pdfmode.def"] then
    if loaded["l3backend-pdfmode.def"] then
      expl3_driver = "pdfmode" -- pdftex, luatex
    elseif loaded["l3backend-dvisvgm.def"] then
      expl3_driver = "dvisvgm"
    elseif loaded["l3backend-xdvipdfmx.def"] then
      expl3_driver = "xdvipdfmx"
    elseif loaded["l3backend-dvipdfmx.def"] then
      expl3_driver = "dvipdfmx"
    elseif loaded["l3backend-dvips.def"] then
      expl3_driver = "dvips"
    else
      -- TODO: driver=latex2e?
      expl3_driver = "unknown"
    end
  end
  local hyperref_driver = nil -- "luatex" | "pdftex" | "xetex" | "dvipdfmx" | "dvips" | "unknown"
  if loaded["hyperref.sty"] then
    if loaded["hluatex.def"] then
      hyperref_driver = "luatex"
    elseif loaded["hpdftex.def"] then
      hyperref_driver = "pdftex"
    elseif loaded["hxetex.def"] then
      hyperref_driver = "xetex"
    elseif loaded["hdvipdfm.def"] then
      hyperref_driver = "dvipdfmx"
    elseif loaded["hdvips.def"] then
      hyperref_driver = "dvips"
    else
      -- Not supported: dvipson, dviwind, tex4ht, texture, vtex, vtexhtm, xtexmrk, hypertex
      hyperref_driver = "unknown"
    end
    -- TODO: dvisvgm?
  end
  local xypic_driver = nil -- "pdf" | "dvips" | "unknown"
  if loaded["xy.tex"] then
    if loaded["xypdf.tex"] then
      xypic_driver = "pdf" -- pdftex, luatex, xetex, dvipdfmx
    elseif loaded["xydvips.tex"] then
      xypic_driver = "dvips"
    else
      -- Not supported: dvidrv, dvitops, oztex, 17oztex, textures, 16textures, xdvi
      xypic_driver = "unknown"
    end
    -- TODO: dvisvgm?
  end

  if CLUTTEX_VERBOSITY >= 1 then
    message.info("checkdriver: graphics=", tostring(graphics_driver))
    message.info("checkdriver: expl3=", tostring(expl3_driver))
    message.info("checkdriver: hyperref=", tostring(hyperref_driver))
    message.info("checkdriver: xypic=", tostring(xypic_driver))
  end

  local expected = assert(right_values[expected_driver], "invalid value for expected_driver")
  if graphics_driver ~= nil and expected.graphics ~= nil and graphics_driver ~= expected.graphics then
    message.diag("The driver option for graphics(x)/color is missing or wrong.")
    message.diag("Consider setting '", expected.graphics, "' option.")
  end
  if expl3_driver ~= nil and expected.expl3 ~= nil and expl3_driver ~= expected.expl3 then
    message.diag("The driver option for expl3 is missing or wrong.")
    message.diag("Consider setting 'driver=", expected.expl3, "' option when loading expl3.")
  end
  if hyperref_driver ~= nil and expected.hyperref ~= nil and hyperref_driver ~= expected.hyperref then
    message.diag("The driver option for hyperref is missing or wrong.")
    message.diag("Consider setting '", expected.hyperref, "' option.")
  end
  if xypic_driver ~= nil and expected.xypic ~= nil and xypic_driver ~= expected.xypic then
    message.diag("The driver option for Xy-pic is missing or wrong.")
    if expected_driver == "dvipdfmx" then
      message.diag("Consider setting 'dvipdfmx' option or running \\xyoption{pdf}.")
    elseif expected_driver == "pdftex" then
      message.diag("Consider setting 'pdftex' option or running \\xyoption{pdf}.")
    elseif expected.xypic == "pdf" then
      message.diag("Consider setting 'pdf' package option or running \\xyoption{pdf}.")
    elseif expected.xypic == "dvips" then
      message.diag("Consider setting 'dvips' option.")
    end
  end
end

--[[
filelist[i] = {path = ""}
]]

return {
  checkdriver = checkdriver,
}
