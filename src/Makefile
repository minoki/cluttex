lua = lua
lunarml = lunarml

ml_sources = \
  md5.sml \
  map.sml \
  shell-util.sml \
  path-util.sml \
  fs-util.sml \
  os-util.sml \
  types.sml \
  safe-name.sml \
  tex-engine.sml \
  message.sml \
  check-driver.sml \
  app-options.sml \
  auxfile.sml \
  luatexinit.sml \
  handle-options.sml \
  recovery.sml \
  reruncheck.sml \
  main.sml

lua_sources = \
  texrunner/fsutil.lua \
  texrunner/luatexinit.lua \
  texrunner/isatty.lua \
  texrunner/pathutil.lua \
  texrunner/pathutil_unix.lua \
  texrunner/pathutil_windows.lua \
  texrunner/shellutil.lua \
  texrunner/shellutil_unix.lua \
  texrunner/shellutil_windows.lua \
  texrunner/fswatcher_windows.lua

all: cluttex.lua cluttex
.PHONY: all

cluttex-ml.lua: cluttex.mlb $(ml_sources)
	$(lunarml) compile -o "$@" cluttex.mlb

cluttex.lua: build.lua cluttex-ml.lua $(lua_sources)
	$(lua) build.lua $@
	$(lua) ../checkglobal.lua $@

cluttex: build.lua cluttex-ml.lua $(lua_sources)
	$(lua) build.lua --unix-shellscript $@
	$(lua) ../checkglobal.lua $@
