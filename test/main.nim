import sqlcipher_abi
import times
import strformat
import os

when isMainModule:
  var
    dbConn: ptr sqlite3
    errorMsg: cstring;
    
  # TODO: create template to check if function results are SQLITE_OK

  if sqlite3_open("./myDatabase", addr dbConn) != SQLITE_OK: 
    echo "ERROR OPENING THE DB!!!!"
    quit()

  var passwd = "qwerty!"
  var res = sqlite3_key(dbConn, passwd.cstring, 7)
  echo res
  if res != SQLITE_OK: 
    echo "ERROR OPENING DB!!!!"
    quit()

  
  if sqlite3_exec(dbConn, "CREATE TABLE IF NOT EXISTS log (theTime TEXT PRIMARY KEY)".cstring, nil, nil, addr errorMsg) != SQLITE_OK:
    echo "ERROR CREATING TABLE!!!", errorMsg
    quit()
  else: 
    echo "Table created or already exists"

  let date = getDateStr(now())
  let time = getClockStr(now())
  if sqlite3_exec(dbConn, &"""INSERT INTO log VALUES("{date}:{time}")""", nil, nil, addr errorMsg) != SQLITE_OK:
    echo "ERROR INSERTING DATA!!!", errorMsg
    quit()
  else:
    echo "Record inserted"

  if sqlite3_close(dbConn) != SQLITE_OK: 
    echo "ERROR CLOSING THE DB!!!!"
  else:
    echo "Fin!"