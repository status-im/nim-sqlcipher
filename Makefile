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
	clean-build-dirs \
	deps \
	sqlcipher \
	sqlite3.c \
	test \
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

all: sqlcipher

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

ifeq ($(OS),Windows_NT) # is Windows_NT on XP, 2000, 7, Vista, 10...
 detected_OS := Windows
else ifeq ($(strip $(shell uname)),Darwin)
 detected_OS := macOS
else
 # e.g. Linux
 detected_OS := $(strip $(shell uname))
endif

clean: | clean-common clean-build-dirs

clean-build-dirs:
	rm -rf \
		lib \
		sqlite \
		test/build

deps: | deps-common

update: | update-common

SSL_STATIC ?= true
SSL_INCLUDE_DIR ?= /usr/include
ifeq ($(SSL_INCLUDE_DIR),)
 override SSL_INCLUDE_DIR = /usr/include
endif
SSL_LIB_DIR ?= /usr/lib/x86_64-linux-gnu
ifeq ($(SSL_LIB_DIR),)
 override SSL_LIB_DIR = /usr/lib/x86_64-linux-gnu
endif
ifndef SSL_LDFLAGS
 ifeq ($(SSL_STATIC),false)
  SSL_LDFLAGS := -L$(SSL_LIB_DIR) -lcrypto
 else
  SSL_LDFLAGS := $(SSL_LIB_DIR)/libcrypto.a
 endif
 ifeq ($(detected_OS),Windows)
  SSL_LDFLAGS += -lws2_32
 endif
endif
ifeq ($(SSL_STATIC),false)
 SSL_LDFLAGS_SQLITE3_C ?= $(SSL_LDFLAGS)
else
 # SQLCipher's configure script fails if SSL_LIB_DIR isn't supplied with -L in LDFLAGS
 SSL_LDFLAGS_SQLITE3_C ?= -L$(SSL_LIB_DIR) $(SSL_LDFLAGS)
endif

SQLCIPHER_STATIC ?= true
SQLCIPHER_CDEFS ?= -DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=3
SQLCIPHER_CFLAGS ?= -I$(SSL_INCLUDE_DIR) -pthread
ifndef SQLCIPHER_LDFLAGS
 ifeq ($(detected_OS),Windows)
  SQLCIPHER_LDFLAGS := -lwinpthread
 else
  SQLCIPHER_LDFLAGS := -lpthread
 endif
endif

SQLITE3_C ?= $(shell pwd)/sqlite/sqlite3.c
SQLITE3_H ?= $(shell pwd)/sqlite/sqlite3.h

$(SQLITE3_C): | deps
	echo -e $(BUILD_MSG) "SQLCipher's SQLite C amalgamation"
	+ mkdir -p sqlite
	cd vendor/sqlcipher && \
		./configure \
			CFLAGS="$(SQLCIPHER_CDEFS) $(SQLCIPHER_CFLAGS)" \
			LDFLAGS="$(SQLCIPHER_LDFLAGS) $(SSL_LDFLAGS_SQLITE3_C)" \
			$(HANDLE_OUTPUT)
	cd vendor/sqlcipher && $(MAKE) sqlite3.c $(HANDLE_OUTPUT)
	cp \
		vendor/sqlcipher/sqlite3.c \
		vendor/sqlcipher/sqlite3.h \
		sqlite/
	cd vendor/sqlcipher && git clean -dfx $(HANDLE_OUTPUT)
	([[ $(detected_OS) = Windows ]] && \
		cd vendor/sqlcipher && \
		git stash $(HANDLE_OUTPUT) && \
		git stash drop $(HANDLE_OUTPUT)) || true

sqlite3.c: $(SQLITE3_C)

SQLCIPHER_STATIC_LIB ?= $(shell pwd)/lib/sqlcipher.a
SQLCIPHER_STATIC_OBJ ?= lib/sqlcipher.o

$(SQLCIPHER_STATIC_LIB): $(SQLITE3_C)
	echo -e $(BUILD_MSG) "SQLCipher static library"
	+ mkdir -p sqlcipher
	$(ENV_SCRIPT) $(CC) \
		$(SQLCIPHER_CDEFS) \
		$(SQLCIPHER_CFLAGS) \
		$(SQLITE3_C) \
		-c \
		-o $(SQLCIPHER_STATIC_OBJ) $(HANDLE_OUTPUT)
	$(ENV_SCRIPT) ar rcs $(SQLCIPHER_STATIC_LIB) $(SQLCIPHER_STATIC_OBJ) $(HANDLE_OUTPUT)

ifndef SHARED_LIB_EXT
 ifeq ($(detected_OS),macOS)
  SHARED_LIB_EXT := dylib
 else ifeq ($(detected_OS),Windows)
  SHARED_LIB_EXT := dll
 else
  SHARED_LIB_EXT := so
 endif
endif

SQLCIPHER_SHARED_LIB ?= $(shell pwd)/lib/libsqlcipher.$(SHARED_LIB_EXT)

ifndef PLATFORM_FLAGS_SHARED_LIB
 ifeq ($(detected_OS),macOS)
  PLATFORM_FLAGS_SHARED_LIB := -shared -dylib
 else
  PLATFORM_FLAGS_SHARED_LIB := -shared -fPIC
 endif
endif

$(SQLCIPHER_SHARED_LIB): $(SQLITE3_C)
	echo -e $(BUILD_MSG) "SQLCipher shared library"
	+ mkdir -p sqlcipher
	$(ENV_SCRIPT) $(CC) \
		$(SQLCIPHER_CDEFS) \
		$(SQLCIPHER_CFLAGS) \
		$(SQLITE3_C) \
		$(SQLCIPHER_LDFLAGS) \
		$(SSL_LDFLAGS) \
		$(PLATFORM_FLAGS_SHARED_LIB) \
		-o $(SQLCIPHER_SHARED_LIB) $(HANDLE_OUTPUT)

ifndef SQLCIPHER_LIB
 ifneq ($(SQLCIPHER_STATIC),false)
  SQLCIPHER_LIB := $(SQLCIPHER_STATIC_LIB)
 else
  SQLCIPHER_LIB := $(SQLCIPHER_SHARED_LIB)
 endif
endif

sqlcipher: $(SQLCIPHER_LIB)

# LD_LIBRARY_PATH is supplied when running tests on Linux
# PATH is supplied when running tests on Windows
ifeq ($(SQLCIPHER_STATIC),false)
 PATH_TEST ?= $(shell dirname $(SQLCIPHER_LIB))::$${PATH}
 ifeq ($(SSL_STATIC),false)
  LD_LIBRARY_PATH_TEST ?= $(shell dirname $(SQLCIPHER_SHARED_LIB)):$(SSL_LIB_DIR)$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}
 else
  LD_LIBRARY_PATH_TEST ?= $(shell dirname $(SQLCIPHER_SHARED_LIB))$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}
 endif
else
 PATH_TEST ?= $${PATH}
 ifeq ($(SSL_STATIC),false)
  LD_LIBRARY_PATH_TEST ?= $(SSL_LIB_DIR)$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}
 else
  LD_LIBRARY_PATH_TEST ?= $${LD_LIBRARY_PATH}
 endif
endif

test: $(SQLCIPHER_LIB)
ifeq ($(detected_OS),macOS)
	SQLCIPHER_LDFLAGS="$(SQLCIPHER_LDFLAGS)" \
	SQLCIPHER_STATIC="$(SQLCIPHER_STATIC)" \
	SSL_LDFLAGS="$(SSL_LDFLAGS)" \
	SSL_STATIC="$(SSL_STATIC)" \
	$(ENV_SCRIPT) nimble tests
else ifeq ($(detected_OS),Windows)
	PATH="$(PATH_TEST)" \
	SQLCIPHER_LDFLAGS="$(SQLCIPHER_LDFLAGS)" \
	SQLCIPHER_STATIC="$(SQLCIPHER_STATIC)" \
	SSL_LDFLAGS="$(SSL_LDFLAGS)" \
	SSL_STATIC="$(SSL_STATIC)" \
	$(ENV_SCRIPT) nimble tests
else
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH_TEST)" \
	SQLCIPHER_LDFLAGS="$(SQLCIPHER_LDFLAGS)" \
	SQLCIPHER_STATIC="$(SQLCIPHER_STATIC)" \
	SSL_LDFLAGS="$(SSL_LDFLAGS)" \
	SSL_STATIC="$(SSL_STATIC)" \
	$(ENV_SCRIPT) nimble tests
endif

endif # "variables.mk" was not included
