#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/exit-protocol.sh"

# Cria ambiente isolado fingindo ser o HOME
FAKE_HOME=$(mktemp -d /tmp/fake_home_test.XXXXXX)
trap 'rm -rf "${FAKE_HOME}"' EXIT

setup_test_dirs() {
    mkdir -p "${FAKE_HOME}/.config/google-chrome/Default"
    mkdir -p "${FAKE_HOME}/.mozilla/firefox/profile.default"
    mkdir -p "${FAKE_HOME}/snap/firefox/common"
    mkdir -p "${FAKE_HOME}/.config/BraveSoftware"
    mkdir -p "${FAKE_HOME}/.config/microsoft-edge"
    echo "historico" > "${FAKE_HOME}/.config/google-chrome/Default/History"
    echo "cookies" > "${FAKE_HOME}/.mozilla/firefox/profile.default/cookies.sqlite"
}

# Carregar script com HOME apontando para o FAKE_HOME
export HOME="${FAKE_HOME}"
source "${TARGET_SCRIPT}"

# 1. Testar se a função kill_running_processes existe
echo "=== Testando declaração de kill_running_processes ==="
if ! declare -F kill_running_processes >/dev/null; then
    echo "FALHA: Função kill_running_processes não está definida!"
    exit 1
fi

# 2. Testar clean_browsers quando desabilitado (CLEAN_BROWSERS=false)
echo "=== Testando clean_browsers com CLEAN_BROWSERS=false ==="
setup_test_dirs
CLEAN_BROWSERS=false
DRY_RUN=false
clean_browsers

if [[ ! -d "${FAKE_HOME}/.config/google-chrome" ]]; then
    echo "FALHA: Diretório foi removido mesmo com CLEAN_BROWSERS=false!"
    exit 1
fi

# 3. Testar clean_browsers em modo DRY_RUN=true
echo "=== Testando clean_browsers em modo DRY_RUN=true ==="
CLEAN_BROWSERS=true
DRY_RUN=true
clean_browsers

if [[ ! -d "${FAKE_HOME}/.config/google-chrome" ]]; then
    echo "FALHA: Diretório foi removido em modo DRY_RUN!"
    exit 1
fi

# 4. Testar clean_browsers com remoção real
echo "=== Testando clean_browsers no sandbox (execução real) ==="
CLEAN_BROWSERS=true
DRY_RUN=false
clean_browsers

if [[ -d "${FAKE_HOME}/.config/google-chrome" ]]; then
    echo "FALHA: Diretório google-chrome ainda existe!"
    exit 1
fi

if [[ -d "${FAKE_HOME}/.mozilla" ]]; then
    echo "FALHA: Diretório .mozilla ainda existe!"
    exit 1
fi

if [[ -d "${FAKE_HOME}/snap/firefox" ]]; then
    echo "FALHA: Diretório snap/firefox ainda existe!"
    exit 1
fi

if [[ -d "${FAKE_HOME}/.config/BraveSoftware" ]]; then
    echo "FALHA: Diretório BraveSoftware ainda existe!"
    exit 1
fi

if [[ -d "${FAKE_HOME}/.config/microsoft-edge" ]]; then
    echo "FALHA: Diretório microsoft-edge ainda existe!"
    exit 1
fi

echo "=== Teste de Navegadores passou com sucesso! ==="
