import sqlcipher_abi

# TODO: ask about this
{.passL: "-lpthread".}
{.passL: "../libcrypto.a".}
{.passC: "-DSQLITE_HAS_CODEC".}

when isMainModule:
  var
    dbConn: ptr sqlite3
    
  # TODO: add template to check if function results are SQLITE_OK

  if sqlite3_open("./myDatabase", addr dbConn) != SQLITE_OK: 
    echo "ERROR!!!!"
    quit()

  var passwd = "qwerty"
  if sqlite3_key(dbConn, addr passwd, 6) != SQLITE_OK: 
    echo "ERROR!!!!"
    quit()

  echo "TODO: create a table, and insert a value"
  
