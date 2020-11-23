import std / [options, macros, typetraits], sugar, sequtils

# sqlcipher/sqlite.nim must be generated before this module can be used.
# To generate it use the `sqlite.nim` target of the Makefile in the same
# directory as this file.
from sqlcipher/sqlite as sqlite import nil
from stew/shims/macros as stew_macros import hasCustomPragmaFixed, getCustomPragmaFixed

# Adapted from https://github.com/GULPF/tiny_sqlite

type
    DbConn* = ptr sqlite.sqlite3

    PreparedSql = sqlite.sqlite3_stmt

    Callback = sqlite.sqlite3_callback

    DbMode* = enum
        dbRead,
        dbReadWrite

    SqliteError* = object of CatchableError ## \
        ## Raised when an error in the underlying SQLite library
        ## occurs.
        errorCode*: int32 ## \
            ## This is the error code that was returned by the underlying
            ## SQLite library.

    DbValueKind* = enum ## \
        ## Enum of all possible value types in a Sqlite database.
        sqliteNull,
        sqliteInteger,
        sqliteReal,
        sqliteText,
        sqliteBlob

    DbValue* = object ## \
        ## Represents a value in a SQLite database.
        case kind*: DbValueKind
        of sqliteInteger:
            intVal*: int64
        of sqliteReal:
            floatVal*: float64
        of sqliteText:
            strVal*: string
        of sqliteBlob:
            blobVal*: seq[byte]
        of sqliteNull:
            discard

    DbColumn* = object
        name*: string
        val*: DbValue

    Tbind_destructor_func* = proc (para1: pointer){.cdecl, locks: 0, tags: [], raises: [], gcsafe.}

const
    SQLITE_STATIC* = nil
    SQLITE_TRANSIENT* = cast[Tbind_destructor_func](-1)

proc newSqliteError(db: DbConn, errorCode: int32): ref SqliteError =
    ## Raises a SqliteError exception.
    (ref SqliteError)(
        msg: $sqlite.errmsg(db),
        errorCode: errorCode
    )

template checkRc(db: DbConn, rc: int32) =
    if rc != sqlite.SQLITE_OK:
        raise newSqliteError(db, rc)

proc prepareSql(db: DbConn, sql: string, params: seq[DbValue]): ptr PreparedSql
        {.raises: [SqliteError].} =
    var tail: cstring
    let rc = sqlite.prepare_v2(db, sql.cstring, sql.len.cint, addr result, addr tail)
    assert tail.len == 0,
        "`exec` and `execMany` can only be used with a single SQL statement. " &
        "To execute several SQL statements, use `execScript`"
    db.checkRc(rc)

    var idx = 1'i32
    for value in params:
        let rc =
            case value.kind
            of sqliteNull:    sqlite.bind_null(result, idx)
            of sqliteInteger:    sqlite.bind_int64(result, idx, value.intval)
            of sqliteReal:  sqlite.bind_double(result, idx, value.floatVal)
            of sqliteText: sqlite.bind_text(result, idx, value.strVal.cstring,
                value.strVal.len.int32, SQLITE_TRANSIENT)
            of sqliteBlob:   sqlite.bind_blob(result, idx.int32,
                cast[string](value.blobVal).cstring,
                value.blobVal.len.int32, SQLITE_TRANSIENT)

        sqlite.db_handle(result).checkRc(rc)
        idx.inc

proc next(prepared: ptr PreparedSql): bool =
    ## Advance cursor by one row.
    ## Return ``true`` if there are more rows.
    let rc = sqlite.step(prepared)
    if rc == sqlite.SQLITE_ROW:
        result = true
    elif rc == sqlite.SQLITE_DONE:
        result = false
    else:
        raise newSqliteError(sqlite.db_handle(prepared), rc)


proc finalize(prepared: ptr PreparedSql) =
    ## Finalize statement or raise SqliteError if not successful.
    let rc = sqlite.finalize(prepared)
    sqlite.db_handle(prepared).checkRc(rc)


proc toDbValue*[T: Ordinal](val: T): DbValue =
    DbValue(kind: sqliteInteger, intVal: val.int64)

proc toDbValue*[T: SomeFloat](val: T): DbValue =
    DbValue(kind: sqliteReal, floatVal: val)

proc toDbValue*[T: string](val: T): DbValue =
    DbValue(kind: sqliteText, strVal: val)

proc toDbValue*[T: seq[byte]](val: T): DbValue =
    DbValue(kind: sqliteBlob, blobVal: val)

proc toDbValue*[T: Option](val: T): DbValue =
    if val.isNone:
        DbValue(kind: sqliteNull)
    else:
        toDbValue(val.get)

when (NimMajor, NimMinor, NimPatch) > (0, 19, 9):
    proc toDbValue*[T: type(nil)](val: T): DbValue =
        DbValue(kind: sqliteNull)

proc nilDbValue(): DbValue =
    ## Since above isn't available for older versions,
    ## we use this internally.
    DbValue(kind: sqliteNull)

proc fromDbValue*(val: DbValue, T: typedesc[Ordinal]): T =
    when T is bool:
        if val.kind == DbValueKind.sqliteText:
            return val.strVal.parseBool
    val.intVal.T

proc fromDbValue*(val: DbValue, T: typedesc[SomeFloat]): float64 = val.floatVal

proc fromDbValue*(val: DbValue, T: typedesc[string]): string = val.strVal

proc fromDbValue*(val: DbValue, T: typedesc[seq[byte]]): seq[byte] = val.blobVal

proc fromDbValue*(val: DbValue, T: typedesc[DbValue]): T = val

proc fromDbValue*[T](val: DbValue, _: typedesc[Option[T]]): Option[T] =
    if (val.kind == sqliteNull) or
        (val.kind == sqliteText and val.strVal == "") or
        (val.kind == sqliteInteger and val.intVal == 0):
        none(T)
    else:
        some(val.fromDbValue(T))


# TODO: uncomment and test
#[
proc unpack*[T: tuple](row: openArray[DbValue], _: typedesc[T]): T =
    ## Call ``fromDbValue`` on each element of ``row`` and return it
    ## as a tuple.
    var idx = 0
    for value in result.fields:
        value = row[idx].fromDbValue(type(value))
        idx.inc

proc `$`*(dbVal: DbValue): string =
    result.add "DbValue["
    case dbVal.kind
    of sqliteInteger: result.add $dbVal.intVal
    of sqliteReal:    result.add $dbVal.floatVal
    of sqliteText:    result.addQuoted dbVal.strVal
    of sqliteBlob:    result.add "<blob>"
    of sqliteNull:    result.add "nil"
    result.add "]"
]#

proc exec*(db: DbConn, sql: string, params: varargs[DbValue, toDbValue]) =
    ## Executes ``sql`` and raises SqliteError if not successful.
    assert (not db.isNil), "Database is nil"
    let prepared = db.prepareSql(sql, @params)
    defer: prepared.finalize()
    discard prepared.next

#[
# TODO: uncomment and test
proc execMany*(db: DbConn, sql: string, params: seq[seq[DbValue]]) =
    ## Executes ``sql`` repeatedly using each element of ``params`` as parameters.
    assert (not db.isNil), "Database is nil"
    for p in params:
        db.exec(sql, p)
]#

proc execScript*(db: DbConn, sql: string) =
    ## Executes the query and raises SqliteError if not successful.
    assert (not db.isNil), "Database is nil"
    let rc = sqlite.exec(db, sql.cstring, nil, nil, nil)
    db.checkRc(rc)

# TODO: uncomment and test
#[
template transaction*(db: DbConn, body: untyped) =
    db.exec("BEGIN")
    var ok = true
    try:
        try:
            body
        except Exception as ex:
            ok = false
            db.exec("ROLLBACK")
            raise ex
    finally:
        if ok:
            db.exec("COMMIT")
]#

proc readColumn(prepared: ptr PreparedSql, col: int32): DbValue {.deprecated: "Use readDbColumn".} =
    let columnType = sqlite.column_type(prepared, col)
    case columnType
    of sqlite.SQLITE_INTEGER:
        result = toDbValue(sqlite.column_int64(prepared, col))
    of sqlite.SQLITE_FLOAT:
        result = toDbValue(sqlite.column_double(prepared, col))
    of sqlite.SQLITE_TEXT:
        result = toDbValue($sqlite.column_text(prepared, col))
    of sqlite.SQLITE_BLOB:
        let blob = sqlite.column_blob(prepared, col)
        let bytes = sqlite.column_bytes(prepared, col)
        var s = newSeq[byte](bytes)
        if bytes != 0:
            copyMem(addr(s[0]), blob, bytes)
        result = toDbValue(s)
    of sqlite.SQLITE_NULL:
        result = nilDbValue()
    else:
        raiseAssert "Unexpected column type: " & $columnType

proc readDbColumn(prepared: ptr PreparedSql, col: int32): DbColumn =
    let
        columnType = sqlite.column_type(prepared, col)
        # FIXME: This is NOT the correct way to get a string from a cstring and
        # may result in loss of data after a NULL termination!
        columnName = $sqlite.column_name(prepared, col)
    case columnType
    of sqlite.SQLITE_INTEGER:
        result = DbColumn(name: columnName, val: toDbValue(sqlite.column_int64(prepared, col)))
    of sqlite.SQLITE_FLOAT:
        result = DbColumn(name: columnName, val: toDbValue(sqlite.column_double(prepared, col)))
    of sqlite.SQLITE_TEXT:
        result = DbColumn(name: columnName, val: toDbValue($sqlite.column_text(prepared, col)))
    of sqlite.SQLITE_BLOB:
        let blob = sqlite.column_blob(prepared, col)
        let bytes = sqlite.column_bytes(prepared, col)
        var s = newSeq[byte](bytes)
        if bytes != 0:
            copyMem(addr(s[0]), blob, bytes)
        result = DbColumn(name: columnName, val: toDbValue(s))
    of sqlite.SQLITE_NULL:
        result = DbColumn(name: columnName, val: nilDbValue())
    else:
        raiseAssert "Unexpected column type: " & $columnType

iterator rows*(db: DbConn, sql: string,
               params: varargs[DbValue, toDbValue]): seq[DbValue] {.deprecated: "Use dbRows".} =
    ## Executes the query and iterates over the result dataset.
    assert (not db.isNil), "Database is nil"
    let prepared = db.prepareSql(sql, @params)
    defer: prepared.finalize()

    var row = newSeq[DbValue](sqlite.column_count(prepared))
    while prepared.next:
        for col, _ in row:
            row[col] = readColumn(prepared, col.int32)
        yield row

proc rows*(db: DbConn, sql: string,
           params: varargs[DbValue, toDbValue]): seq[seq[DbValue]] {.deprecated: "Use dbRows".} =
    ## Executes the query and returns the resulting rows.
    for row in db.rows(sql, params):
        result.add row

iterator dbRows*(db: DbConn, sql: string,
               params: varargs[DbValue, toDbValue]): seq[DbColumn] =
    ## Executes the query and iterates over the result dataset.
    assert (not db.isNil), "Database is nil"
    let prepared = db.prepareSql(sql, @params)
    defer: prepared.finalize()

    var row = newSeq[DbColumn](sqlite.column_count(prepared))
    while prepared.next:
        for col, _ in row:
            row[col] = readDbColumn(prepared, col.int32)
        yield row

proc dbRows*(db: DbConn, sql: string,
           params: varargs[DbValue, toDbValue]): seq[seq[DbColumn]] =
    ## Executes the query and returns the resulting rows.
    for row in db.dbRows(sql, params):
        result.add row

proc openDatabase*(path: string, mode = dbReadWrite): DbConn =
    ## Open a new database connection to a database file. To create a
    ## in-memory database the special path `":memory:"` can be used.
    ## If the database doesn't already exist and ``mode`` is ``dbReadWrite``,
    ## the database will be created. If the database doesn't exist and ``mode``
    ## is ``dbRead``, a ``SqliteError`` exception will be raised.
    ##
    ## NOTE: To avoid memory leaks, ``db.close`` must be called when the
    ## database connection is no longer needed.
    runnableExamples:
        let memDb = openDatabase(":memory:")
    case mode
    of dbReadWrite:
        let rc = sqlite.open(path, addr result)
        result.checkRc(rc)
    of dbRead:
        let rc = sqlite.open_v2(path, addr result, sqlite.SQLITE_OPEN_READONLY, nil)
        result.checkRc(rc)

proc key*(db: DbConn, password: string) =
    let rc = sqlite.key(db, password.cstring, int32(password.len))
    db.checkRc(rc)

proc rekey*(db: DbConn, password: string) =
    let rc = sqlite.rekey(db, password.cstring, int32(password.len))
    db.checkRc(rc)

proc close*(db: DbConn) =
    ## Closes the database connection.
    let rc = sqlite.close(db)
    db.checkRc(rc)

# TODO: test
#[

proc lastInsertRowId*(db: DbConn): int64 =
    ## Get the row id of the last inserted row.
    ## For tables with an integer primary key,
    ## the row id will be the primary key.
    ##
    ## For more information, refer to the SQLite documentation
    ## (https://www.sqlite.org/c3ref/last_insert_rowid.html).
    sqlite.last_insert_rowid(db)

proc changes*(db: DbConn): int32 =
    ## Get the number of changes triggered by the most recent INSERT, UPDATE or
    ## DELETE statement.
    ##
    ## For more information, refer to the SQLite documentation
    ## (https://www.sqlite.org/c3ref/changes.html).
    sqlite.changes(db)

proc isReadonly*(db: DbConn): bool =
    ## Returns true if ``db`` is in readonly mode.
    sqlite.db_readonly(db, "main") == 1
]#

proc col*[T](row: seq[DbColumn], columnName: string, _: typedesc[T]): T =
    let results = row.filter((column: DbColumn) => column.name == columnName)
    if results.len == 0:
        return default(T)
    results[0].val.fromDbValue(T)

template dbColumnName*(name: string) {.pragma.}
    ## Specifies the database column name for the object property

template enumInstanceDbColumns*(obj: auto,
                                fieldNameVar, fieldVar,
                                body: untyped) =
    ## Expands a block over all serialized fields of an object.
    ##
    ## Inside the block body, the passed `fieldNameVar` identifier
    ## will refer to the name of each field as a string. `fieldVar`
    ## will refer to the field value.
    ##
    ## The order of visited fields matches the order of the fields in
    ## the object definition unless `serialziedFields` is used to specify
    ## a different order. Fields marked with the `dontSerialize` pragma
    ## are skipped.
    ##
    ## If the visited object is a case object, only the currently active
    ## fields will be visited. During de-serialization, case discriminators
    ## will be read first and the iteration will continue depending on the
    ## value being deserialized.
    ##
    type ObjType {.used.} = type(obj)

    for fieldName, fieldVar in fieldPairs(obj):
        when hasCustomPragmaFixed(ObjType, fieldName, dbColumnName):
            const fieldNameVar = getCustomPragmaFixed(ObjType, fieldName, dbColumnName)
        else:
            const fieldNameVar = fieldName
        body

proc to*(row: seq[DbColumn], obj: var object) =
    obj.enumInstanceDbColumns(dbColName, property):
        type ColType = type property
        property = row.col(dbColName, ColType)

proc hasRows*(rows: seq[seq[DbColumn]]): bool = rows.len > 0
