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
  ../src/texrunner/fsutil.lua \
  ../src/texrunner/luatexinit.lua \
  ../src/texrunner/isatty.lua \
  ../src/texrunner/pathutil.lua \
  ../src/texrunner/pathutil_unix.lua \
  ../src/texrunner/pathutil_windows.lua \
  ../src/texrunner/shellutil.lua \
  ../src/texrunner/shellutil_unix.lua \
  ../src/texrunner/shellutil_windows.lua \
  ../src/texrunner/fswatcher_windows.lua

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
