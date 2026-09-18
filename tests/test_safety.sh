#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/protocolo-demissao.sh"

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

echo "=== Testes de Segurança passaram com sucesso! ==="
