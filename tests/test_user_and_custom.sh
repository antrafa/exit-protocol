#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/protocolo-demissao.sh"

FAKE_HOME=$(mktemp -d /tmp/fake_user_test.XXXXXX)
CUSTOM_TEST_DIR=$(mktemp -d /tmp/fake_custom_dir.XXXXXX)
trap 'rm -rf "${FAKE_HOME}" "${CUSTOM_TEST_DIR}"' EXIT

mkdir -p "${FAKE_HOME}/Downloads"
touch "${FAKE_HOME}/Downloads/meu_boleto.pdf"
touch "${FAKE_HOME}/Downloads/foto.png"

mkdir -p "${FAKE_HOME}/.vscode"
mkdir -p "${FAKE_HOME}/.config/Slack"

mkdir -p "${FAKE_HOME}/.local/share/Trash/files"
touch "${FAKE_HOME}/.local/share/Trash/files/arquivo_deletado.txt"

touch "${FAKE_HOME}/.bash_history"
touch "${FAKE_HOME}/.zsh_history"

touch "${CUSTOM_TEST_DIR}/codigo_secreto.py"

export HOME="${FAKE_HOME}"
source "${TARGET_SCRIPT}" --source-only

CUSTOM_PATHS=("${CUSTOM_TEST_DIR}")
DRY_RUN=false

echo "=== Testando pastas pessoais, custom paths, trash e historico ==="
clean_ides
clean_communication
clean_user_dirs
clean_custom_paths
clean_trash
clean_shell_history

# Verifica se a pasta Downloads existe, mas seu conteúdo foi apagado
if [[ ! -d "${FAKE_HOME}/Downloads" ]]; then
    echo "FALHA: A pasta Downloads em si foi apagada!"
    exit 1
fi
if [[ -f "${FAKE_HOME}/Downloads/meu_boleto.pdf" ]]; then
    echo "FALHA: O arquivo dentro de Downloads não foi apagado!"
    exit 1
fi

# Verifica se IDEs e Mensageiros foram apagados
if [[ -e "${FAKE_HOME}/.vscode" ]]; then
    echo "FALHA: .vscode ainda existe!"
    exit 1
fi
if [[ -e "${FAKE_HOME}/.config/Slack" ]]; then
    echo "FALHA: .config/Slack ainda existe!"
    exit 1
fi

# Verifica se custom path foi apagado
if [[ -e "${CUSTOM_TEST_DIR}" ]]; then
    echo "FALHA: CUSTOM_PATH ainda existe!"
    exit 1
fi

# Verifica se bash_history foi apagado
if [[ -f "${FAKE_HOME}/.bash_history" ]]; then
    echo "FALHA: .bash_history ainda existe!"
    exit 1
fi

echo "=== Teste de Pastas de Usuário e Custom Paths passou com sucesso! ==="
