#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/exit-protocol.sh"

echo "=== Testando --help ==="
output=$("${TARGET_SCRIPT}" --help)
if [[ "${output}" != *"Uso: "* ]]; then
    echo "FALHA: --help não retornou instrução de uso."
    exit 1
fi

echo "=== Testando safe_remove com caminho proibido (/) ==="
export TEST_RUN=1
source "${TARGET_SCRIPT}" --source-only 2>/dev/null || true

# Testar se safe_remove bloqueia caminhos críticos
if safe_remove "/" 0 2>/dev/null; then
    echo "FALHA: safe_remove não bloqueou /"
    exit 1
fi

if safe_remove "" 0 2>/dev/null; then
    echo "FALHA: safe_remove não bloqueou caminho vazio"
    exit 1
fi

echo "=== Testando safe_remove com \$HOME ==="
if safe_remove "${HOME}" 0 2>/dev/null; then
    echo "FALHA: safe_remove não bloqueou \$HOME"
    exit 1
fi

echo "=== Testando bypass da lista negra via caminho relativo ==="
if safe_remove "${HOME}/qualquer/../../$(basename "${HOME}")" 0 2>/dev/null; then
    echo "FALHA: safe_remove não bloqueou grafia relativa do \$HOME"
    exit 1
fi

echo "=== Testando remoção de symlink quebrado ==="
TEST_TMP=$(mktemp -d /tmp/safety_test_symlink.XXXXXX)
ln -s "${TEST_TMP}/nonexistent_target" "${TEST_TMP}/broken_link"
if [[ ! -L "${TEST_TMP}/broken_link" ]]; then
    echo "FALHA: Não foi possível criar symlink de teste"
    exit 1
fi
safe_remove "${TEST_TMP}/broken_link"
if [[ -L "${TEST_TMP}/broken_link" ]]; then
    echo "FALHA: safe_remove não removeu symlink quebrado"
    rm -rf "${TEST_TMP}"
    exit 1
fi
rm -rf "${TEST_TMP}"

echo "=== Testes de Segurança passaram com sucesso! ==="
