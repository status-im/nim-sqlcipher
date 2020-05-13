import sqlcipher
import times
import strformat
import os

when isMainModule:
  let db: DbConn = openDatabase("./myDatabase")

  let passwd = "qwerty"

  key(db, passwd)

  execScript(db, "create table if not exists Log (theTime text primary key)")

  let date = getDateStr(now())
  let time = getClockStr(now())

  execScript(db, &"""insert into Log values("{date}:{time}")""")

  #echo rows(db, "select * from Log")
