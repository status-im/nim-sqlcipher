import # nim libs
  options, os, unittest, strformat

import # vendor libs
  ../sqlcipher

type
  BoolTest* {.dbTableName("boolTest").} = object
    testId* {.dbColumnName("testId").}: string
    boolCol1* {.dbColumnName("boolCol1").}: bool
    boolCol2* {.dbColumnName("boolCol2").}: bool
    boolCol3* {.dbColumnName("boolCol3").}: Option[bool]
  SqliteBool = bool | int | string | Option[bool]

proc createBoolTable(db: DbConn) =
  var boolTest: BoolTest
  db.exec(fmt"""CREATE TABLE {boolTest.tableName} (
      {boolTest.testId.columnName} VARCHAR NOT NULL PRIMARY KEY,
      {boolTest.boolCol1.columnName} BOOLEAN,
      {boolTest.boolCol2.columnName} BOOLEAN DEFAULT TRUE,
      {boolTest.boolCol3.columnName} BOOLEAN
    )""")

proc getBoolRow(db: DbConn, testId: string): BoolTest =
  var boolTest: BoolTest
  let query = fmt"""SELECT * FROM {boolTest.tableName} WHERE {boolTest.testId.columnName} = ?"""
  let resultOption = db.one(BoolTest, query, testId)
  if resultOption.isNone:
    raise newException(ValueError, fmt"Failed to get row with testId '{testId}'")
  resultOption.get()

proc insertBoolRowString(db: DbConn, testId: string, bool1: SqliteBool, bool2: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  let bool3Param = if bool3.isNone: "null" else: fmt"'{bool3.get}'"
  db.execScript(fmt"""INSERT INTO {boolTest.tableName} VALUES ('{testId}', '{bool1}', '{bool2}', {bool3Param});""")
  db.getBoolRow(testId)

proc insertBoolRowString(db: DbConn, testId: string, bool1: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  let bool3Param = if bool3.isNone: "null" else: fmt"'{bool3.get}'"
  db.execScript(fmt"""
    INSERT INTO {boolTest.tableName} (
      {boolTest.testId.columnName}, {boolTest.boolCol1.columnName}, {boolTest.boolCol3.columnName}
    )
    VALUES (
      '{testId}', '{bool1}', {bool3Param}
    );""")
  db.getBoolRow(testId)

proc insertBoolRowInt(db: DbConn, testId: string, bool1: SqliteBool, bool2: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  let bool3Param = if bool3.isNone: "null" else: fmt"{bool3.get}"
  db.execScript(fmt"""INSERT INTO {boolTest.tableName} VALUES ('{testId}', {bool1}, {bool2}, {bool3Param});""")
  db.getBoolRow(testId)

proc insertBoolRowInt(db: DbConn, testId: string, bool1: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  let bool3Param = if bool3.isNone: "null" else: fmt"{bool3.get}"
  db.execScript(fmt"""INSERT INTO {boolTest.tableName} ({boolTest.testId.columnName}, {boolTest.boolCol1.columnName}, {boolTest.boolCol3.columnName}) VALUES ('{testId}', {bool1}, {bool3Param});""")
  db.getBoolRow(testId)

proc insertBoolRowBool(db: DbConn, testId: string, bool1: SqliteBool, bool2: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  db.exec(fmt"""INSERT INTO {boolTest.tableName} VALUES (?, ?, ?, ?);""", testId, bool1, bool2, bool3)
  db.getBoolRow(testId)

proc insertBoolRowBool(db: DbConn, testId: string, bool1: SqliteBool, bool3: Option[SqliteBool]): BoolTest =
  var boolTest: BoolTest
  db.exec(fmt"""INSERT INTO {boolTest.tableName} ({boolTest.testId.columnName}, {boolTest.boolCol1.columnName}, {boolTest.boolCol3.columnName}) VALUES (?, ?, ?);""", testId, bool1, bool3)
  db.getBoolRow(testId)

suite "sqlite_booleans":
  let password = "qwerty"
  let path = currentSourcePath.parentDir() & "/build/my.db"
  removeFile(path)
  let db = openDatabase(path)
  db.key(password)
  debugEcho "creating bool test table"
  db.createBoolTable()
  
  test "using nim boolean types":
    let falseFalseNone1 = db.insertBoolRowBool("falseFalseNone1", false, false, bool.none)
    let falseTrueFalse1 = db.insertBoolRowBool("falseTrueFalse1", false, false.some)
    let trueFalseNone1 = db.insertBoolRowBool("trueFalseNone1", true, false, bool.none)
    let trueTrueTrue1 = db.insertBoolRowBool("trueTrueTrue1", true, true.some)

    check:
      falseFalseNone1 == BoolTest(testId: "falseFalseNone1", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse1 == BoolTest(testId: "falseTrueFalse1", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone1 == BoolTest(testId: "trueFalseNone1", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue1 == BoolTest(testId: "trueTrueTrue1", boolCol1: true, boolCol2: true, boolCol3: true.some)

  test "using strings":
    let falseFalseNone2 = db.insertBoolRowString("falseFalseNone2", "false", "false", string.none)
    let falseTrueFalse2 = db.insertBoolRowString("falseTrueFalse2", "false", "false".some)
    let trueFalseNone2 = db.insertBoolRowString("trueFalseNone2", "true", "false", string.none)
    let trueTrueTrue2 = db.insertBoolRowString("trueTrueTrue2", "true", "true".some)
    
    check:
      falseFalseNone2 == BoolTest(testId: "falseFalseNone2", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse2 == BoolTest(testId: "falseTrueFalse2", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone2 == BoolTest(testId: "trueFalseNone2", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue2 == BoolTest(testId: "trueTrueTrue2", boolCol1: true, boolCol2: true, boolCol3: true.some)
      

  test "using uppercase strings":
    let falseFalseNone3 = db.insertBoolRowString("falseFalseNone3", "FALSE", "FALSE", string.none)
    let falseTrueFalse3 = db.insertBoolRowString("falseTrueFalse3", "FALSE", "FALSE".some)
    let trueFalseNone3 = db.insertBoolRowString("trueFalseNone3", "TRUE", "FALSE", string.none)
    let trueTrueTrue3 = db.insertBoolRowString("trueTrueTrue3", "TRUE", "TRUE".some)

    check:
      falseFalseNone3 == BoolTest(testId: "falseFalseNone3", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse3 == BoolTest(testId: "falseTrueFalse3", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone3 == BoolTest(testId: "trueFalseNone3", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue3 == BoolTest(testId: "trueTrueTrue3", boolCol1: true, boolCol2: true, boolCol3: true.some)


  test "using ints":
    let falseFalseNone4 = db.insertBoolRowInt("falseFalseNone4", 0, 0, int.none)
    let falseTrueFalse4 = db.insertBoolRowInt("falseTrueFalse4", 0, 0.some)
    let trueFalseNone4 = db.insertBoolRowInt("trueFalseNone4", 1, 0, int.none)
    let trueTrueTrue4 = db.insertBoolRowInt("trueTrueTrue4", 1, 1.some)

    check:
      falseFalseNone4 == BoolTest(testId: "falseFalseNone4", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse4 == BoolTest(testId: "falseTrueFalse4", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone4 == BoolTest(testId: "trueFalseNone4", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue4 == BoolTest(testId: "trueTrueTrue4", boolCol1: true, boolCol2: true, boolCol3: true.some)

  test "using string ints":
    let falseFalseNone5 = db.insertBoolRowString("falseFalseNone5", "0", "0", string.none)
    let falseTrueFalse5 = db.insertBoolRowString("falseTrueFalse5", "0", "0".some)
    let trueFalseNone5 = db.insertBoolRowString("trueFalseNone5", "1", "0", string.none)
    let trueTrueTrue5 = db.insertBoolRowString("trueTrueTrue5", "1", "1".some)

    check:
      falseFalseNone5 == BoolTest(testId: "falseFalseNone5", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse5 == BoolTest(testId: "falseTrueFalse5", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone5 == BoolTest(testId: "trueFalseNone5", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue5 == BoolTest(testId: "trueTrueTrue5", boolCol1: true, boolCol2: true, boolCol3: true.some)

  # Nim's standard lib strutils.parseBool supports yes/no and on/off, see
  # https://nim-lang.org/docs/strutils.html#parseBool%2Cstring for more information.
  # The following tests are just to illustrate support for these values, as well.

  test "using yes/no":
    let falseFalseNone6 = db.insertBoolRowString("falseFalseNone6", "no", "no", string.none)
    let falseTrueFalse6 = db.insertBoolRowString("falseTrueFalse6", "no", "no".some)
    let trueFalseNone6 = db.insertBoolRowString("trueFalseNone6", "yes", "no", string.none)
    let trueTrueTrue6 = db.insertBoolRowString("trueTrueTrue6", "yes", "yes".some)

    check:
      falseFalseNone6 == BoolTest(testId: "falseFalseNone6", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse6 == BoolTest(testId: "falseTrueFalse6", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone6 == BoolTest(testId: "trueFalseNone6", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue6 == BoolTest(testId: "trueTrueTrue6", boolCol1: true, boolCol2: true, boolCol3: true.some)

  test "using on/off":
    let falseFalseNone7 = db.insertBoolRowString("falseFalseNone7", "off", "off", string.none)
    let falseTrueFalse7 = db.insertBoolRowString("falseTrueFalse7", "off", "off".some)
    let trueFalseNone7 = db.insertBoolRowString("trueFalseNone7", "on", "off", string.none)
    let trueTrueTrue7 = db.insertBoolRowString("trueTrueTrue7", "on", "on".some)

    check:
      falseFalseNone7 == BoolTest(testId: "falseFalseNone7", boolCol1: false, boolCol2: false, boolCol3: bool.none)
      falseTrueFalse7 == BoolTest(testId: "falseTrueFalse7", boolCol1: false, boolCol2: true, boolCol3: false.some)
      trueFalseNone7 == BoolTest(testId: "trueFalseNone7", boolCol1: true, boolCol2: false, boolCol3: bool.none)
      trueTrueTrue7 == BoolTest(testId: "trueTrueTrue7", boolCol1: true, boolCol2: true, boolCol3: true.some)

  db.close()
  removeFile(path)
