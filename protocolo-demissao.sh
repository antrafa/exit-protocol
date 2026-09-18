#!/usr/bin/env bash
# ==============================================================================
# PROTOCOLO DE DEMISSÃO - Higienização de Estações Ubuntu Linux
# ==============================================================================
set -eo pipefail

# --- CONFIGURAÇÃO DE ATIVAÇÃO DOS MÓDULOS ---
CLEAN_BROWSERS=true          # Google Chrome, Chromium, Firefox, Brave, Edge
CLEAN_DEV_CREDENTIALS=true   # SSH, GPG, Git configs e tokens
CLEAN_CLOUD_INFRA=true       # AWS, GCP, Azure, Kubernetes, Docker
CLEAN_DEV_TOKENS=true        # npm, pip, cargo, composer, gradle, maven, .netrc
CLEAN_IDES=true              # VS Code, JetBrains, Cursor
CLEAN_COMMUNICATION=true     # Slack, Discord, Microsoft Teams, Telegram
CLEAN_USER_DIRS=true         # Downloads, Documentos, Desktop, Imagens, Vídeos, Música
CLEAN_SHELL_HISTORY=true     # .bash_history, .zsh_history e histórico de terminal
CLEAN_TRASH=true             # Lixeira do Ubuntu (~/.local/share/Trash)

# --- PASTAS CUSTOMIZADAS ---
CUSTOM_PATHS=(
    # "$HOME/projetos"
    # "$HOME/workspace"
)

# --- CORES E FORMATAÇÃO ---
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_CYAN="\033[1;36m"
COLOR_GRAY="\033[0;90m"

log_info()    { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"; }
log_warn()    { echo -e "${COLOR_YELLOW}[AVISO]${COLOR_RESET} $*"; }
log_error()   { echo -e "${COLOR_RED}[ERRO]${COLOR_RESET} $*"; }
log_dry()     { echo -e "${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} $*"; }
log_skip()    { echo -e "${COLOR_GRAY}[IGNORADO]${COLOR_RESET} $*"; }

DRY_RUN=false
FORCE=false

check_not_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        log_error "Este script NÃO deve ser executado com sudo ou como root!"
        log_error "Execute como o usuário comum dono dos arquivos que serão limpos."
        exit 1
    fi
}

safe_remove() {
    local target="$1"
    local content_only="${2:-0}"

    if [[ -z "${target}" ]]; then
        return 1
    fi

    # Normalizar caminho
    local clean_target
    clean_target="$(echo "${target}" | sed 's:/*$::')"
    [[ -z "${clean_target}" ]] && clean_target="/"

    # Lista negra de segurança absoluta
    case "${clean_target}" in
        "/"|"/home"|"/root"|"/bin"|"/boot"|"/dev"|"/etc"|"/lib"|"/lib64"|"/usr"|"/var"|"/proc"|"/sys"|"/tmp")
            log_error "Tentativa de remoção de caminho crítico bloqueada: ${target}"
            return 1
            ;;
    esac

    if [[ "${content_only}" -eq 1 ]]; then
        if [[ ! -d "${target}" ]]; then
            log_skip "Diretório não existe: ${target}"
            return 0
        fi

        local count
        count=$(find "${target}" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        if [[ "${count}" -eq 0 ]]; then
            log_skip "Diretório já está vazio: ${target}"
            return 0
        fi

        if [[ "${DRY_RUN}" == true ]]; then
            log_dry "Esvaziaria o conteúdo de: ${target} (${count} itens)"
        else
            find "${target}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
            log_success "Conteúdo esvaziado: ${target}"
        fi
        return 0
    fi

    if [[ ! -e "${target}" ]]; then
        log_skip "Não encontrado: ${target}"
        return 0
    fi

    local size="-"
    size=$(du -sh "${target}" 2>/dev/null | cut -f1 || echo "-")

    if [[ "${DRY_RUN}" == true ]]; then
        log_dry "Removeria: ${target} (${size})"
    else
        rm -rf -- "${target}" 2>/dev/null || true
        log_success "Removido: ${target} (${size})"
    fi
}

show_help() {
    cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Script seguro para higienização e protocolo de desligamento no Ubuntu Linux.

Opções:
  --dry-run       Simula a execução e lista tudo o que seria removido sem alterar nada.
  --force         Pula a confirmação manual via digitação de 'CONFIRMAR'.
  -h, --help      Exibe esta ajuda.

Edite o topo do arquivo $(basename "$0") para habilitar/desabilitar módulos ou adicionar pastas em CUSTOM_PATHS.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --source-only)
                return 0
                ;;
            *)
                log_error "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

confirm_execution() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "Modo de simulação ativo (--dry-run). NENHUM arquivo será modificado."
        return 0
    fi

    if [[ "${FORCE}" == true ]]; then
        log_warn "Flag --force informada. Prosseguindo sem prompt de confirmação."
        return 0
    fi

    echo
    echo -e "${COLOR_RED}============================== ATENÇÃO ==============================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Este script apagará dados de histórico, credenciais e pastas configuradas!${COLOR_RESET}"
    echo -e "${COLOR_RED}Essa ação é irreversível.${COLOR_RESET}"
    echo -e "${COLOR_RED}=====================================================================${COLOR_RESET}"
    echo
    read -rp "Para confirmar a execução, digite exatamente 'CONFIRMAR': " response
    if [[ "${response}" != "CONFIRMAR" ]]; then
        log_info "Execução cancelada pelo usuário."
        exit 0
    fi
}

# Se chamado diretamente (não como source em teste)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_not_root
    parse_args "$@"
    confirm_execution
fi
