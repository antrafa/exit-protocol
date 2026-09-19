#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/exit-protocol.sh"

FAKE_HOME=$(mktemp -d /tmp/fake_cred_test.XXXXXX)
trap 'rm -rf "${FAKE_HOME}"' EXIT

mkdir -p "${FAKE_HOME}/.ssh"
mkdir -p "${FAKE_HOME}/.aws"
mkdir -p "${FAKE_HOME}/.kube"
mkdir -p "${FAKE_HOME}/.docker"
touch "${FAKE_HOME}/.ssh/id_rsa"
touch "${FAKE_HOME}/.gitconfig"
touch "${FAKE_HOME}/.git-credentials"
touch "${FAKE_HOME}/.npmrc"
touch "${FAKE_HOME}/.pypirc"

export HOME="${FAKE_HOME}"
source "${TARGET_SCRIPT}"

echo "=== Testando clean_dev_credentials, clean_cloud_infra e clean_dev_tokens ==="
DRY_RUN=false
clean_dev_credentials
clean_cloud_infra
clean_dev_tokens

for path in ".ssh" ".aws" ".kube" ".docker" ".gitconfig" ".git-credentials" ".npmrc" ".pypirc"; do
    if [[ -e "${FAKE_HOME}/${path}" ]]; then
        echo "FALHA: ${path} ainda existe!"
        exit 1
    fi
done

echo "=== Teste de Credenciais passou com sucesso! ==="
