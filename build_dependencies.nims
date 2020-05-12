import os

let OpenSSL = "openssl-1.1.1g"
let SQLCipher = "sqlcipher-4.3.0"

# libcripto ===========================================
exec "curl https://www.openssl.org/source/" & OpenSSL & ".tar.gz --output " & OpenSSL & ".tar.gz"
exec "tar -zxvf " & OpenSSL & ".tar.gz"
rmFile OpenSSL & ".tar.gz"
withDir OpenSSL:
  exec "./config -shared"
  exec "make -j`nproc`"
# Linux specific. Add `when` for different OS
cpFile(thisDir() / OpenSSL / "libcrypto.a", thisDir() / "libcrypto.a")
rmDir OpenSSL

# sqlite3.c ===========================================
exec "curl -LJO https://github.com/sqlcipher/sqlcipher/archive/v4.3.0.tar.gz --output " & SQLCipher & ".tar.gz"
exec "tar -zxvf " & SQLCipher & ".tar.gz"
rmFile SQLCipher & ".tar.gz"
withDir SQLCipher:
  # Linux specific
  exec """./configure --enable-tempstore=yes CFLAGS="-DSQLITE_HAS_CODEC" LDFLAGS="../libcrypto.a""""
  exec "make sqlite3.c"
cpFile(thisDir() / SQLCipher / "sqlite3.c", thisDir() / "sqlite3.c") 
cpFile(thisDir() / SQLCipher / "sqlite3.h", thisDir() / "sqlite3.h") 
rmDir SQLCipher
