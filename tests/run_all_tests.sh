#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Executando suíte completa de testes do Protocolo de Demissão..."
echo "---------------------------------------------------------------"

"${SCRIPT_DIR}/test_safety.sh"
"${SCRIPT_DIR}/test_browsers.sh"
"${SCRIPT_DIR}/test_credentials.sh"
"${SCRIPT_DIR}/test_user_and_custom.sh"

echo "---------------------------------------------------------------"
echo "TODOS OS TESTES PASSARAM COM SUCESSO!"
