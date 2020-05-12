# Package

packageName   = "sqlcipher_abi"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "A wrapper for SQLCipher"
license       = "MIT"

# Dependencies
requires "nim >= 1.0.0"
requires "nimterop >= 0.5.2"

before install:
  exec "nim e build_dependencies.nims"
  exec "./gen-wrapper.sh"

# TODO: read nimterop documentation for remove the need for build_depenencies.nim
# TODO: see https://github.com/nimterop/nimterop/wiki/Wrappers