mode = ScriptMode.Verbose

version     = "0.1.0"
author      = "Status Research & Development GmbH"
description = "A wrapper for SQLCipher"
license     = "MIT"
skipDirs    = @["test"]

requires "nim >= 1.2.0",
  "nimterop"

import strutils

proc buildAndRunTest(name: string,
                     srcDir = "test/",
                     outDir = "test/build/",
                     params = "",
                     cmdParams = "",
                     lang = "c") =
  rmdir outDir
  mkDir outDir
  # allow something like "nim test --verbosity:0 --hints:off beacon_chain.nims"
  var extra_params = params
  for i in 2..<paramCount():
    extra_params &= " " & paramStr(i)
  exec "nim " &
    lang &
    " --debugger:native" &
    " --define:debug" &
    " --define:ssl" &
    " --nimcache:nimcache/test/" & name &
    " --out:" & outDir & name &
    (if getEnv("SSL_LDFLAGS").strip != "": " --passL:\"" & getEnv("SSL_LDFLAGS") & "\"" else: "") &
    " --threads:on" &
    " --tlsEmulation:off" &
    " " &
    extra_params &
    " " &
    srcDir & name & ".nim" &
    " " &
    cmdParams
  exec outDir & name

task tests, "Run all tests":
  buildAndRunTest "db_smoke"
