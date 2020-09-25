import macros
import nimterop/cimport
import os
import strutils

macro dynamicCdefine(): untyped =
  var cdefs: seq[string]
  for cdef in split(getEnv("SQLITE_CDEFS"), "-D"):
    let stripped = strip(cdef)
    if stripped != "":
      cdefs.add(stripped)
  result = newStmtList()
  for cdef in cdefs:
    result.add(newCall("cDefine", newStrLitNode(cdef)))

static:
  cDebug()

  cSkipSymbol(@[
    "sqlite3_version",
    "sqlite3_destructor_type"
  ])

  dynamicCdefine()

  when getEnv("SQLITE_STATIC") == "false":
    cPassL("-L" & splitPath($getEnv("SQLITE_LIB")).head & " " & "-lsqlite3")
  when getEnv("SQLITE_STATIC") != "false":
    cPassL($getEnv("SQLITE_LIB"))

cPlugin:
  import strutils

  var i = 0;

  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
    # Remove prefixes or suffixes from procs
    if sym.kind == nskProc and sym.name.contains("sqlite3_"):
      sym.name = sym.name.replace("sqlite3_", "")
    # Workaround for duplicate iColumn symbol in generated Nim code
    # (but generated code for sqlite3_index_info is likely not usable anyway)
    if sym.name.contains("iColumn"):
      if i == 0:
        sym.name = sym.name.replace("iColumn", "iColumn_index_constraint")
      else:
        sym.name = sym.name.replace("iColumn", "iColumn_index_orderby")
      i += 1

cImport($getEnv("SQLITE3_H"), flags = "-f:ast2")
