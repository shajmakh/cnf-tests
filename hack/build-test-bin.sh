#!/bin/bash

set -e
set +x

. $(dirname "$0")/common.sh

if ! which go; then
  echo "No go command available"
  exit 1
fi

GOPATH="${GOPATH:-~/go}"
export GOFLAGS="${GOFLAGS:-"-mod=vendor"}"

export PATH=$PATH:$GOPATH/bin
pushd submodules/cluster-node-tuning-operator
echo "Building latency tools ... "
make dist-latency-tests
popd
