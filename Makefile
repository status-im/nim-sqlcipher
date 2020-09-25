# Copyright (c) 2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by Make

# used inside the included makefiles
BUILD_SYSTEM_DIR := vendor/nimbus-build-system

# we don't want an error here, so we can handle things later, in the ".DEFAULT" target
-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk

.PHONY: \
	all \
	clean \
	deps \
	sqlite \
	sqlite.nim \
	sqlite3.c \
	test \
	toast \
	update

ifeq ($(NIM_PARAMS),)
# "variables.mk" was not included, so we update the submodules.
GIT_SUBMODULE_UPDATE := git submodule update --init --recursive
.DEFAULT:
	+@ echo -e "Git submodules not found. Running '$(GIT_SUBMODULE_UPDATE)'.\n"; \
		$(GIT_SUBMODULE_UPDATE); \
		echo
# Now that the included *.mk files appeared, and are newer than this file, Make will restart itself:
# https://www.gnu.org/software/make/manual/make.html#Remaking-Makefiles
#
# After restarting, it will execute its original goal, so we don't have to start a child Make here
# with "$(MAKE) $(MAKECMDGOALS)". Isn't hidden control flow great?

else # "variables.mk" was included. Business as usual until the end of this file.

all: sqlite.nim

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

ifeq ($(OS),Windows_NT) # is Windows_NT on XP, 2000, 7, Vista, 10...
 detected_OS := Windows
else ifeq ($(strip $(shell uname)),Darwin)
 detected_OS := macOS
else
 detected_OS := $(strip $(shell uname)) # e.g. Linux
endif

clean: | clean-common
	rm -rf \
		$(NIMTEROP_TOAST) \
		$(NIMTEROP_TOAST).dSYM \
		generator/generate \
		generator/generate.exe \
		generator/generate.dSYM \
		sqlcipher \
		sqlite \
		test/build

deps: | deps-common

update: | update-common

SQLITE_CDEFS ?= -DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=3
SQLITE_CFLAGS ?= -pthread
ifndef SQLITE_LDFLAGS
 ifneq ($(detected_OS),macOS)
  SQLITE_LDFLAGS := -pthread
 endif
endif
SQLITE_STATIC ?= true

SSL_INCLUDE_DIR ?= /usr/include
ifeq ($(SSL_INCLUDE_DIR),)
 override SSL_INCLUDE_DIR = /usr/include
endif
SSL_LIB_DIR ?= /usr/lib/x86_64-linux-gnu
ifeq ($(SSL_LIB_DIR),)
 override SSL_LIB_DIR = /usr/lib/x86_64-linux-gnu
endif

SSL_CFLAGS ?= -I$(SSL_INCLUDE_DIR)
SSL_STATIC ?= true
ifndef SSL_LDFLAGS
 ifeq ($(SSL_STATIC),false)
  SSL_LDFLAGS := -L$(SSL_LIB_DIR) -lcrypto
 else
  SSL_LDFLAGS := -L$(SSL_LIB_DIR) $(SSL_LIB_DIR)/libcrypto.a
 endif
 ifeq ($(detected_OS),Windows)
  SSL_LDFLAGS += -lws2_32
 endif
endif

SQLITE3_C ?= sqlite/sqlite3.c
SQLITE3_H ?= $(CURDIR)/sqlite/sqlite3.h

$(SQLITE3_C): | deps
ifeq ($(detected_OS),Windows)
	sed -i "s/tr -d '\\\\\\n'/tr -d '\\\\\\r\\\\\\n'/" vendor/sqlcipher/configure
endif
	echo -e $(BUILD_MSG) "SQLCipher's SQLite C amalgamation"
	+ cd vendor/sqlcipher && \
		./configure \
			CFLAGS="$(SQLITE_CDEFS) $(SQLITE_CFLAGS) $(SSL_CFLAGS)" \
			LDFLAGS="$(SQLITE_LDFLAGS) $(SSL_LDFLAGS)" \
			$(HANDLE_OUTPUT)
ifeq ($(detected_OS),Windows)
	sed -E -i "s/TOP = \\/([A-Za-z])/TOP = \\u\\1:/" vendor/sqlcipher/Makefile
endif
	cd vendor/sqlcipher && $(MAKE) sqlite3.c $(HANDLE_OUTPUT)
	mkdir -p sqlite
	cp vendor/sqlcipher/sqlite3.c sqlite/
	cp vendor/sqlcipher/sqlite3.h sqlite/
	cd vendor/sqlcipher && \
		git clean -dfx $(HANDLE_OUTPUT) && \
		(git stash $(HANDLE_OUTPUT) || true) && \
		(git stash drop $(HANDLE_OUTPUT) || true)

sqlite3.c: $(SQLITE3_C)

SQLITE_STATIC_LIB ?= $(CURDIR)/sqlite/sqlite3.a

$(SQLITE_STATIC_LIB): $(SQLITE3_C)
	echo -e $(BUILD_MSG) "SQLCipher static library"
	+ $(ENV_SCRIPT) $(CC) \
		-c \
		sqlite/sqlite3.c \
		$(SQLITE_CDEFS) \
		$(SQLITE_CFLAGS) \
		$(SSL_CFLAGS) \
		-o sqlite/sqlite3.o $(HANDLE_OUTPUT)
	$(ENV_SCRIPT) ar rcs $(SQLITE_STATIC_LIB) sqlite/sqlite3.o $(HANDLE_OUTPUT)

ifndef SHARED_LIB_EXT
 ifeq ($(detected_OS),macOS)
  SHARED_LIB_EXT := dylib
 else ifeq ($(detected_OS),Windows)
  SHARED_LIB_EXT := dll
 else
  SHARED_LIB_EXT := so
 endif
endif

SQLITE_SHARED_LIB ?= $(CURDIR)/sqlite/libsqlite3.$(SHARED_LIB_EXT)

ifndef PLATFORM_LINKER_FLAGS
 ifeq ($(detected_OS),macOS)
  PLATFORM_LINKER_FLAGS := -dylib
 endif
endif

$(SQLITE_SHARED_LIB): $(SQLITE3_C)
	echo -e $(BUILD_MSG) "SQLCipher shared library"
	+ $(ENV_SCRIPT) $(CC) \
		-c -fPIC \
		sqlite/sqlite3.c \
		$(SQLITE_CDEFS) \
		$(SQLITE_CFLAGS) \
		$(SSL_CFLAGS) \
		-o sqlite/sqlite3.o $(HANDLE_OUTPUT)
	$(ENV_SCRIPT) ld \
		$(PLATFORM_LINKER_FLAGS) \
		-undefined dynamic_lookup \
		sqlite/sqlite3.o \
		-o $(SQLITE_SHARED_LIB) $(HANDLE_OUTPUT)

ifndef SQLITE_LIB
 ifneq ($(SQLITE_STATIC),false)
  SQLITE_LIB := $(SQLITE_STATIC_LIB)
 else
  SQLITE_LIB := $(SQLITE_SHARED_LIB)
 endif
endif

sqlite: $(SQLITE_LIB)

ifndef NIMTEROP_TOAST
 ifeq ($(detected_OS),Windows)
  NIMTEROP_TOAST := vendor/nimterop/nimterop/toast.exe
 else
  NIMTEROP_TOAST := vendor/nimterop/nimterop/toast
 endif
endif

$(NIMTEROP_TOAST): | deps
	echo -e $(BUILD_MSG) "Nimterop toast"
	+ cd vendor/nimterop && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) \
			--define:danger \
			--hints:off \
			--nimcache:../../nimcache/nimterop \
			nimterop/toast.nim
	rm -rf $(NIMTEROP_TOAST).dSYM

toast: $(NIMTEROP_TOAST)

SQLITE_NIM ?= sqlcipher/sqlite.nim

$(SQLITE_NIM): $(NIMTEROP_TOAST) $(SQLITE_LIB)
	echo -e $(BUILD_MSG) "Nim wrapper for SQLCipher"
	+ mkdir -p sqlcipher
	SQLITE_CDEFS="$(SQLITE_CDEFS)"\
	SQLITE_STATIC="$(SQLITE_STATIC)" \
	SQLITE3_H="$(SQLITE3_H)" \
	SQLITE_LIB="$(SQLITE_LIB)" \
	$(ENV_SCRIPT) nim c $(NIM_PARAMS) \
		--nimcache:nimcache/sqlcipher \
		--verbosity:0 \
		generator/generate.nim > sqlcipher/sqlite.nim 2> /dev/null
	rm -rf generator/generate generator/generate.exe generator/generate.dSYM

sqlite.nim: $(SQLITE_NIM)

test: $(SQLITE_NIM)
	SSL_LDFLAGS="$(SSL_LDFLAGS)" \
	$(ENV_SCRIPT) nimble tests

endif # "variables.mk" was not included
