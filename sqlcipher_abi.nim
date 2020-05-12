import nimterop/[cimport, build, paths]
import os, strutils

const
  baseDir = getProjectCacheDir("sqlcipher_abi") 

static:
   # uses va_list which is undefined
  cSkipSymbol(@[
    # uses va_list which is undefined
    "sqlite3_vmprintf",
    "sqlite3_vsnprintf",
    "sqlite3_str_vappendf",
    
    "sqlite3_destructor_type"
    ])

  gitPull("https://github.com/sqlcipher/sqlcipher", outdir = baseDir, checkout = "v4.4.0")

  configure(baseDir, "Makefile", """--enable-tempstore=yes CFLAGS="-DSQLITE_HAS_CODEC" LDFLAGS="-lcrypto"""")

  make(baseDir, "sqlite3.c", "sqlite3.c")

  {.passC: "-DSQLITE_HAS_CODEC".}

  # TODO: determine if these are OS specific
  {.passL: "-lpthread".}
  {.passL: "-lcrypto".}

  cDefine("SQLITE_HAS_CODEC")

  cCompile(baseDir / "sqlite3.c")

cImport(baseDir/"sqlite3.h", flags = "-f:ast2")

#TODO: flag for static linking?