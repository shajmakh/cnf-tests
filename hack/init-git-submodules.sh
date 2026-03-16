#!/bin/bash

cd "$(dirname "$0")"/..

set -x
set -e

echo "cluster-node-tuning-operator target commit: ${CLUSTER_NODE_TUNING_OPERATOR_TARGET_COMMIT}"

cd submodules/cluster-node-tuning-operator/
git fetch --all
git checkout origin/"${CLUSTER_NODE_TUNING_OPERATOR_TARGET_COMMIT}"

make vet
