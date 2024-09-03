lua = lua
lunarml = lunarml
smlfmt = smlfmt
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
  src/ansi-color.sml \
  src/message.sml \
  src/check-driver.sml \
  src/app-options.sml \
  src/auxfile.sml \
  src/luatexinit.sml \
  src/handle-options.sml \
  src/recovery.sml \
  src/reruncheck.sml \
  src/config-file.sml \
  src/main.sml

# smlfmt doesn't support vector expressions #[], record extension { ... = <exp> }, record update { ... where ... }
non_formatted_sources = \
  src/shell-util.sml \
  src/path-util.sml \
  src/fs-util.sml \
  src/os-util.sml \
  src/tex-engine.sml \
  src/message.sml \
  src/luatexinit.sml \
  src/handle-options.sml \
  src/reruncheck.sml \
  src/main.sml

formatted_sources = $(filter-out $(non_formatted_sources),$(ml_sources))

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

.PHONY: format
format:
	$(smlfmt) --force $(formatted_sources)

.PHONY: check-format
check-format:
	$(smlfmt) --check $(formatted_sources)

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
