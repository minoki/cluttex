lua = lua
lunarml = lunarml
VERSION = 0.7.0

ml_sources = \
  src/md5.sml \
  src/map.sml \
  src/shell-util.sml \
  src/path-util.sml \
  src/fs-util.sml \
  src/os-util.sml \
  src/types.sml \
  src/safe-name.sml \
  src/tex-engine.sml \
  src/message.sml \
  src/check-driver.sml \
  src/app-options.sml \
  src/auxfile.sml \
  src/luatexinit.sml \
  src/handle-options.sml \
  src/recovery.sml \
  src/reruncheck.sml \
  src/main.sml

lua_sources = \
  src/texrunner/fsutil.lua \
  src/texrunner/luatexinit.lua \
  src/texrunner/isatty.lua \
  src/texrunner/pathutil.lua \
  src/texrunner/pathutil_unix.lua \
  src/texrunner/pathutil_windows.lua \
  src/texrunner/shellutil.lua \
  src/texrunner/shellutil_unix.lua \
  src/texrunner/shellutil_windows.lua \
  src/texrunner/fswatcher_windows.lua

all: bin/cluttex.lua bin/cluttex
.PHONY: all

src/cluttex-ml.lua: src/cluttex.mlb $(ml_sources)
	$(lunarml) compile -o "$@" src/cluttex.mlb

bin/cluttex.lua: build.lua src/cluttex-ml.lua $(lua_sources)
	@mkdir -p bin
	$(lua) build.lua $@
	$(lua) checkglobal.lua $@

bin/cluttex: build.lua src/cluttex-ml.lua $(lua_sources)
	@mkdir -p bin
	$(lua) build.lua --unix-shellscript $@
	$(lua) checkglobal.lua $@
	chmod +x $@

version_file=$(shell bin/cluttex --version 2>&1 | grep --only-matching -E 'v[[:digit:]]+(\.[[:digit:]]+)*' | sed 's/^v/VERSION_/;s/\./_/g')

check-version: all
	@bin/cluttex --version
	@$(lua) bin/cluttex.lua --version
	grep VERSION src/main.sml
	grep -i VERSION doc/cluttex.tex
	grep -i VERSION doc/cluttex-ja.tex
.PHONY: check-version

archive: all check-version
	touch $(version_file)
	git archive -o "cluttex-$(VERSION).tar.gz" --prefix=cluttex/bin/ --add-file=bin/cluttex --prefix=cluttex/ --add-file=$(version_file) HEAD
	git archive -o "cluttex-$(VERSION).zip" --prefix=cluttex/bin/ --add-file=bin/cluttex --prefix=cluttex/ --add-file=$(version_file) HEAD
.PHONY: archive
