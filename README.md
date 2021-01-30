# nim-sqlcipher
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/Stability-experimental-orange.svg)
[![Tests (GitHub Actions)](https://github.com/status-im/nim-sqlcipher/workflows/Tests/badge.svg?branch=master)](https://github.com/status-im/nim-sqlcipher/actions?query=workflow%3ATests+branch%3Amaster)

Nim wrapper for [SQLCipher](https://github.com/sqlcipher/sqlcipher). It builds SQLCipher and provides a simple API based on [tiny_sqlite](https://github.com/GULPF/tiny_sqlite).

## Requirements
```
# Linux
sudo apt install libssl-dev

# MacOS
brew install openssl

# Windows (msys2)
pacman -S mingw-w64-x86_64-openssl
```

## Usage

TODO

## License

### Wrapper License

Licensed and distributed under the [MIT License](https://github.com/status-im/nim-sqlcipher/blob/master/LICENSE).

### Dependency Licenses

- SQLCipher https://github.com/sqlcipher/sqlcipher/blob/master/LICENSE
- OpenSSL https://github.com/openssl/openssl/blob/master/LICENSE
- TinySQLite https://github.com/GULPF/tiny_sqlite/blob/master/LICENSE
