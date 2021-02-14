include sqlcipher/tiny_sqlite

#
# Custom.DbConn
#
proc all*[T](db: DbConn, _: typedesc[T], sql: string,
        params: varargs[DbValue, toDbValue]): seq[T] =
    ## Executes ``statement`` and returns all result rows.
    for row in db.iterate(sql, params):
        var r = T()
        row.unpack(r)
        result.add r

proc one*[T](db: DbConn, _: typedesc[T], sql: string,
        params: varargs[DbValue, toDbValue]): Option[T] =
    ## Executes `sql`, which must be a single SQL statement, and returns the first result row.
    ## Returns `none(seq[DbValue])` if the result was empty.
    for row in db.iterate(sql, params):
        var r = T()
        row.unpack(r)
        return some(r)

proc value*[T](db: DbConn, _: typedesc[T], sql: string,
        params: varargs[DbValue, toDbValue]): Option[T] =
    ## Executes `sql`, which must be a single SQL statement, and returns the first column of the first result row.
    ## Returns `none(DbValue)` if the result was empty.
    for row in db.iterate(sql, params):
        return some(row.values[0].fromDbValue(T))

#
# Custom.SqlStatement
#
proc all*[T](_: typedesc[T], statement: SqlStatement, params: varargs[DbValue, toDbValue]): seq[T] =
    ## Executes ``statement`` and returns all result rows.
    assertCanUseStatement statement
    for row in statement.iterate(params):
        var r = T()
        row.unpack(r)
        result.add r

proc one*[T](_: typedesc[T], statement: SqlStatement,
        params: varargs[DbValue, toDbValue]): Option[T] =
    ## Executes `statement` and returns the first row found.
    ## Returns `none(seq[DbValue])` if no result was found.
    assertCanUseStatement statement
    for row in statement.iterate(params):
        var r = T()
        row.unpack(r)
        return some(r)

proc value*[T](_: typedesc[T], statement: SqlStatement,
        params: varargs[DbValue, toDbValue]): Option[T] =
    ## Executes `statement` and returns the first column of the first row found.
    ## Returns `none(DbValue)` if no result was found.
    assertCanUseStatement statement
    for row in statement.iterate(params):
        return some(row.values[0].fromDbValue(T))

#
# Custom.ResultRow
#
proc `[]`*[T](row: ResultRow, columnName: string, _: typedesc[T]): T =
    row[columnName].fromDbValue(T)

proc hasRows*(rows: seq[ResultRow]): bool = rows.len > 0

#
# Custom.ORM
# This section was not originally part of tiny_sqlite
#

# TODO: add primaryKey param to pragma, however there is an issue with multiple
# params in getCustomPragmaFixed: https://github.com/status-im/nim-stew/issues/62,
# and we need to wait on a fix or a workaround.
template dbColumnName*(name: string) {.pragma.}
    ## Specifies the database column name for the object property

template dbIgnore*() {.pragma.}
    ## Specifies the object property should not be considered a DB column

template dbTableName*(name: string) {.pragma.}
    ## Specifies the database table name for the object

template dbForeignKey*(t: typedesc) {.pragma.}
    ## Specifies the table's foreign key type

template columnName*(obj: auto | typedesc): string =
    when macros.hasCustomPragma(obj, dbColumnName):
        macros.getCustomPragmaVal(obj, dbColumnName)
    else:
        typetraits.name(obj.type).toLower

template tableName*(obj: auto | typedesc): string =
    when macros.hasCustomPragma(obj, dbTableName):
        macros.getCustomPragmaVal(obj, dbTableName)
    else:
        typetraits.name(obj.type).toLower


template enumInstanceDbColumns*(obj: auto,
                                fieldNameVar, fieldVar, fieldIgnore,
                                body: untyped) =
    ## Expands a block over all fields of an object.
    ##
    ## Inside the block body, the passed `fieldNameVar` identifier
    ## will refer to the name of each field as a string. `fieldVar`
    ## will refer to the field value.
    ##
    ## The order of visited fields matches the order of the fields in
    ## the object definition.
    type ObjType {.used.} = type(obj)

    for fieldName, fieldVar in fieldPairs(obj):
        when hasCustomPragmaFixed(ObjType, fieldName, dbIgnore):
            const fieldIgnore = true
            const fieldNameVar = fieldName
        elif hasCustomPragmaFixed(ObjType, fieldName, dbColumnName):
            const fieldIgnore = false
            const fieldNameVar = getCustomPragmaFixed(ObjType, fieldName, dbColumnName)
        else:
            const fieldIgnore = false
            const fieldNameVar = fieldName
        body

proc unpack*(row: ResultRow, obj: var object) =
    obj.enumInstanceDbColumns(dbColName, property, ignore):
        if not ignore:
            type ColType = type property
            property = row[dbColName, ColType]

#
# Custom.sqlcipher
# The following are APIs from sqlcipher
#
proc key*(db: DbConn, password: string) =
    ##  * Specify the key for an encrypted database.  This routine should be
    ##  * called right after sqlite3_open().
    ##  *
    ##  * The code to implement this API is not available in the public release
    ##  * of SQLite.
    let rc = sqlite.key(db.handle, password.cstring, int32(password.len))
    db.checkRc(rc)

proc key_v2*(db: DbConn, zDbName, password: string) =
    ##  * Specify the key for an encrypted database.  This routine should be
    ##  * called right after sqlite3_open().
    ##  *
    ##  * The code to implement this API is not available in the public release
    ##  * of SQLite.
    let rc = sqlite.key_v2(db.handle, zDbName.cstring, password.cstring, int32(password.len))
    db.checkRc(rc)

proc rekey*(db: DbConn, password: string) =
    let rc = sqlite.rekey(db.handle, password.cstring, int32(password.len))
    db.checkRc(rc)
    ##  * Change the key on an open database.  If the current database is not
    ##  * encrypted, this routine will encrypt it.  If pNew==0 or nNew==0, the
    ##  * database is decrypted.
    ##  *
    ##  * The code to implement this API is not available in the public release
    ##  * of SQLite.

proc rekey_v2*(db: DbConn, zDbName, password: string) =
    ##  * Change the key on an open database.  If the current database is not
    ##  * encrypted, this routine will encrypt it.  If pNew==0 or nNew==0, the
    ##  * database is decrypted.
    ##  *
    ##  * The code to implement this API is not available in the public release
    ##  * of SQLite.
    let rc = sqlite.rekey_v2(db.handle, zDbName.cstring, password.cstring, int32(password.len))
    db.checkRc(rc)

#
# Custom.Deprecations
#
proc execQuery*[T](db: DbConn, sql: string, params: varargs[DbValue, toDbValue]): seq[T] {.deprecated: "Use all[T] instead".} =
    ## Executes the query and iterates over the result dataset.
    all[T](db, sql, T.type, params)
