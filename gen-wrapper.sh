#!/bin/bash
[[ -v HAS_NIMTEROP ]] || nimble install -y nimterop@0.5.2

nim c --hints:off wrap.nim > sqlcipher_abi.nim
./wrap