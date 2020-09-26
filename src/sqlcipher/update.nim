import nimterop/[cimport, build]
import os

const
  baseDir = getProjectCacheDir("nim-sqlcipher") 

static:
  cDebug()

  gitPull("https://github.com/sqlcipher/sqlcipher", outdir = baseDir, checkout = "v4.4.0")

  configure(baseDir, "./Makefile", """--enable-tempstore=yes CFLAGS="-DSQLITE_HAS_CODEC" LDFLAGS="-lcrypto"""")

  make(baseDir, "sqlite3.c", "sqlite3.c")

  {.passC: "-DSQLITE_HAS_CODEC".}

  # TODO: determine if these are OS specific
  {.passL: "-lpthread".}
  {.passL: "-lcrypto".}

   # uses va_list which is undefined
  cSkipSymbol(@[
    "sqlite3_version",
    # uses va_list which is undefined
    "sqlite3_vmprintf",
    "sqlite3_vsnprintf",
    "sqlite3_str_vappendf",
    "sqlite3_destructor_type"
    ])

  cDefine("SQLITE_HAS_CODEC")

cCompile(baseDir / "sqlite3.c")

cPlugin:
  import strutils

  # Symbol renaming examples
  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =    # Remove prefixes or suffixes from procs
    if sym.kind == nskProc and sym.name.contains("sqlite3_"):
      sym.name = sym.name.replace("sqlite3_", "")

cImport(baseDir/"sqlite3.h", flags = "-f:ast2")


#TODO: flag for static linking?