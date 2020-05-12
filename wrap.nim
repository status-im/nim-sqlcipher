import nimterop/cimport

static:
  cDebug()

  # uses va_list which is undefined
  cSkipSymbol(@[
    "sqlite3_activate_see",
    # uses va_list which is undefined
    "sqlite3_vmprintf",
    "sqlite3_vsnprintf",
    "sqlite3_str_vappendf",
    # can use native nim types instead
    "sqlite_int64",
    "sqlite_uint64",
    "sqlite3_int64",
    "sqlite3_uint64",
    ])

cDefine("SQLITE_HAS_CODEC") 

cPlugin:
  import strutils

  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
    if sym.kind == nskType:
      case sym.name
      of "sqlite_int64", "sqlite3_int64": sym.name = "int64"
      of "sqlite_uint64", "sqlite3_uint64": sym.name = "uint64"

{.passC: "-DSQLITE_HAS_CODEC".}

 # TODO: This is probably linux specific
{.passL: "-lpthread".}
{.passL: "libcrypto.a".}

cImport("sqlite3.h")
cCompile("sqlite3.c")

echo sqlite3_libversion()