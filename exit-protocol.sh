#!/usr/bin/env bash
# ==============================================================================
# EXIT PROTOCOL - Workstation Sanitization & Offboarding (Ubuntu Linux)
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
    # "$HOME/minha-pasta-privada"
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
log_error()   { echo -e "${COLOR_RED}[ERRO]${COLOR_RESET} $*" >&2; }
log_dry()     { echo -e "${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} $*"; }
log_skip()    { echo -e "${COLOR_GRAY}[IGNORADO]${COLOR_RESET} $*"; }

DRY_RUN=false
FORCE=false
FAILED_COUNT=0

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
        log_error "Alvo vazio ignorado."
        return 1
    fi

    # A canonicalização serve só para VALIDAR: sem ela "$HOME/projetos/../../$USER"
    # escapa da lista negra abaixo por ser outra grafia do mesmo diretório.
    # As operações seguem usando o caminho original, senão um symlink quebrado
    # seria resolvido para o alvo inexistente e nunca removido.
    local clean_target home_real
    clean_target="$(realpath -m -- "${target}")"
    home_real="$(realpath -m -- "${HOME:-/nonexistent}")"

    # Lista negra de segurança absoluta
    case "${clean_target}" in
        "/"|"/home"|"/root"|"/bin"|"/boot"|"/dev"|"/etc"|"/lib"|"/lib64"|"/usr"|"/var"|"/proc"|"/sys"|"/tmp")
            log_error "Tentativa de remoção de caminho crítico bloqueada: ${target}"
            return 1
            ;;
    esac

    if [[ -n "${HOME}" && "${clean_target}" == "${home_real}" ]]; then
        log_error "Tentativa de remoção da pasta HOME bloqueada: ${target}"
        return 1
    fi

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
            return 0
        fi

        find "${target}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true

        local remaining
        remaining=$(find "${target}" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        if [[ "${remaining}" -gt 0 ]]; then
            log_error "FALHOU ao esvaziar (${remaining} item(ns) restante(s)): ${target}"
            return 1
        fi
        log_success "Conteúdo esvaziado: ${target}"
        return 0
    fi

    if [[ ! -e "${target}" && ! -L "${target}" ]]; then
        log_skip "Não encontrado: ${target}"
        return 0
    fi

    local size
    size=$(du -sh "${target}" 2>/dev/null | cut -f1 || echo "-")

    if [[ "${DRY_RUN}" == true ]]; then
        log_dry "Removeria: ${target} (${size})"
        return 0
    fi

    rm -rf -- "${target}" 2>/dev/null || true

    # O propósito do script é garantir que o dado sumiu: só declara sucesso
    # depois de conferir. Arquivo imutável, permissão negada ou disco em
    # somente-leitura passariam despercebidos de outro modo.
    if [[ -e "${target}" || -L "${target}" ]]; then
        log_error "FALHOU ao remover: ${target}"
        return 1
    fi
    log_success "Removido: ${target} (${size})"
}

# Contabiliza a falha em vez de deixar 'set -e' abortar o protocolo inteiro no
# meio: um alvo bloqueado não pode impedir a limpeza dos módulos seguintes.
remove_all() {
    local target
    for target in "$@"; do
        safe_remove "${target}" || FAILED_COUNT=$((FAILED_COUNT + 1))
    done
}

remove_contents() {
    local target
    for target in "$@"; do
        safe_remove "${target}" 1 || FAILED_COUNT=$((FAILED_COUNT + 1))
    done
}

# --- MÓDULO: NAVEGADORES E PROCESSOS ---

kill_running_processes() {
    [[ "${DRY_RUN}" == true ]] && { log_dry "Simulação: encerraria processos de navegadores e aplicativos"; return 0; }
    log_info "Encerrando processos de navegadores e aplicativos..."
    local apps=(
        "chrome" "google-chrome" "chromium" "chromium-browser"
        "firefox" "brave" "brave-browser" "msedge" "microsoft-edge"
        "slack" "discord" "teams" "telegram-desktop"
    )
    # Padrão ancorado em '/' e terminado por espaço/fim de linha. 'pkill -f chrome'
    # casaria 'tail -f chrome.log' ou o próprio script se ele morasse em
    # ~/chrome-tools/, matando a execução no meio.
    for app in "${apps[@]}"; do
        if pkill -u "${USER}" -f "/${app}( |\$)" 2>/dev/null; then
            log_info "Processo encerrado: ${app}"
        fi
    done
    sleep 1
}

clean_browsers() {
    [[ "${CLEAN_BROWSERS}" != true ]] && return 0
    log_info "Limpando navegadores (histórico, perfis, cache e cookies)..."

    local browser_targets=(
        # Google Chrome / Chromium
        "${HOME}/.config/google-chrome"
        "${HOME}/.cache/google-chrome"
        "${HOME}/.config/chromium"
        "${HOME}/.cache/chromium"
        "${HOME}/snap/chromium"
        "${HOME}/snap/google-chrome"
        "${HOME}/.var/app/com.google.Chrome"
        "${HOME}/.var/app/org.chromium.Chromium"

        # Mozilla Firefox
        "${HOME}/.mozilla"
        "${HOME}/.cache/mozilla"
        "${HOME}/snap/firefox"
        "${HOME}/.var/app/org.mozilla.firefox"

        # Brave
        "${HOME}/.config/BraveSoftware"
        "${HOME}/.cache/BraveSoftware"
        "${HOME}/snap/brave"
        "${HOME}/.var/app/com.brave.Browser"

        # Microsoft Edge
        "${HOME}/.config/microsoft-edge"
        "${HOME}/.cache/microsoft-edge"
        "${HOME}/.var/app/com.microsoft.Edge"

        # Opera / Vivaldi
        "${HOME}/.config/opera"
        "${HOME}/.config/vivaldi"
    )

    remove_all "${browser_targets[@]}"
}

# --- MÓDULO: CREDENCIAIS DE DESENVOLVIMENTO, NUVEM E TOKENS ---

clean_dev_credentials() {
    [[ "${CLEAN_DEV_CREDENTIALS}" != true ]] && return 0
    log_info "Limpando credenciais de desenvolvimento (SSH, GPG, Git)..."

    # Encerrar cache de credenciais do git em memória
    if [[ "${DRY_RUN}" != true ]]; then
        git credential-cache exit 2>/dev/null || true
    fi

    local cred_targets=(
        "${HOME}/.ssh"
        "${HOME}/.gnupg"
        "${HOME}/.gitconfig"
        "${HOME}/.git-credentials"
        "${HOME}/.config/git"

        # Keyring do GNOME: guarda a chave que descriptografa os cookies do
        # Chrome e as senhas salvas do sistema. Apagar só o perfil do navegador
        # deixa esse material para trás.
        "${HOME}/.local/share/keyrings"
        "${HOME}/.pki"
        "${HOME}/.password-store"

        # CLIs que persistem token de acesso
        "${HOME}/.config/gh"
        "${HOME}/.config/glab"
        "${HOME}/.config/op"
    )

    remove_all "${cred_targets[@]}"
}

clean_cloud_infra() {
    [[ "${CLEAN_CLOUD_INFRA}" != true ]] && return 0
    log_info "Limpando configurações de nuvem e DevOps (AWS, GCP, Azure, Kube, Docker)..."

    local cloud_targets=(
        "${HOME}/.aws"
        "${HOME}/.config/gcloud"
        "${HOME}/.azure"
        "${HOME}/.kube"
        "${HOME}/.minikube"
        "${HOME}/.k9s"
        "${HOME}/.docker"
        "${HOME}/.terraform.d"
        "${HOME}/.terraformrc"
        "${HOME}/.config/helm"
        "${HOME}/.cache/helm"
        "${HOME}/.vault-token"
        "${HOME}/.config/rclone"
    )

    remove_all "${cloud_targets[@]}"
}

clean_dev_tokens() {
    [[ "${CLEAN_DEV_TOKENS}" != true ]] && return 0
    log_info "Limpando tokens de gerenciadores de pacotes..."

    local token_targets=(
        "${HOME}/.npmrc"
        "${HOME}/.yarnrc"
        "${HOME}/.yarnrc.yml"
        "${HOME}/.config/pnpm"
        "${HOME}/.pip/pip.conf"
        "${HOME}/.pypirc"
        "${HOME}/.cargo/credentials"
        "${HOME}/.cargo/credentials.toml"
        "${HOME}/.composer/auth.json"
        "${HOME}/.config/composer/auth.json"
        "${HOME}/.m2/settings.xml"
        "${HOME}/.m2/settings-security.xml"
        "${HOME}/.gradle/gradle.properties"
        "${HOME}/.netrc"
    )

    remove_all "${token_targets[@]}"
}

# --- MÓDULO: IDES E EDITORES ---

clean_ides() {
    [[ "${CLEAN_IDES}" != true ]] && return 0
    log_info "Limpando workspaces e histórico de IDEs (VS Code, JetBrains, Cursor)..."

    local ide_targets=(
        "${HOME}/.config/Code/User/workspaceStorage"
        "${HOME}/.config/Code/User/globalStorage"
        "${HOME}/.config/Code/User/history"
        "${HOME}/.config/Code/Backups"
        "${HOME}/.vscode"
        "${HOME}/snap/code"
        "${HOME}/.config/Cursor"
        "${HOME}/.cursor"
        "${HOME}/.config/VSCodium"
        "${HOME}/.config/JetBrains"
        "${HOME}/.local/share/JetBrains"
        "${HOME}/.cache/JetBrains"
    )

    remove_all "${ide_targets[@]}"
}

# --- MÓDULO: COMUNICAÇÃO ---

clean_communication() {
    [[ "${CLEAN_COMMUNICATION}" != true ]] && return 0
    log_info "Limpando dados e sessões de aplicativos de comunicação..."

    local comm_targets=(
        "${HOME}/.config/Slack"
        "${HOME}/.cache/Slack"
        "${HOME}/snap/slack"
        "${HOME}/.var/app/com.slack.Slack"
        "${HOME}/.config/discord"
        "${HOME}/snap/discord"
        "${HOME}/.var/app/com.discordapp.Discord"
        "${HOME}/.config/teams"
        "${HOME}/.config/Microsoft/Microsoft Teams"
        "${HOME}/.var/app/com.microsoft.Teams"
        "${HOME}/.local/share/TelegramDesktop"
        "${HOME}/snap/telegram-desktop"
        "${HOME}/.var/app/org.telegram.desktop"
    )

    remove_all "${comm_targets[@]}"
}

# --- MÓDULO: PASTAS PESSOAIS E CUSTOMIZADAS ---

clean_user_dirs() {
    [[ "${CLEAN_USER_DIRS}" != true ]] && return 0
    log_info "Esvaziando conteúdo das pastas pessoais..."

    local user_dirs=(
        "${HOME}/Downloads"
        "${HOME}/Documents"
        "${HOME}/Documentos"
        "${HOME}/Desktop"
        "${HOME}/Área de Trabalho"
        "${HOME}/Pictures"
        "${HOME}/Imagens"
        "${HOME}/Videos"
        "${HOME}/Vídeos"
        "${HOME}/Music"
        "${HOME}/Música"
    )

    remove_contents "${user_dirs[@]}"
}

clean_custom_paths() {
    if [[ ${#CUSTOM_PATHS[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Processando pastas customizadas configuradas em CUSTOM_PATHS..."
    local custom expanded home_real
    home_real="$(realpath -m -- "${HOME:-/nonexistent}")"

    for custom in "${CUSTOM_PATHS[@]}"; do
        # Expandir til (~) se presente
        expanded="$(realpath -m -- "${custom/#\~/$HOME}")"

        # CUSTOM_PATHS é o único alvo que vem de edição manual e o mais perigoso
        # do script: qualquer coisa fora do HOME é erro de configuração.
        if [[ "${expanded}" != "${home_real}/"* ]]; then
            log_error "Fora do HOME, ignorado: ${custom}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            continue
        fi

        safe_remove "${expanded}" || FAILED_COUNT=$((FAILED_COUNT + 1))
    done
}

# --- MÓDULO: LIXEIRA E HISTÓRICOS ---

clean_trash() {
    [[ "${CLEAN_TRASH}" != true ]] && return 0
    log_info "Esvaziando Lixeira..."

    remove_contents "${HOME}/.local/share/Trash"
}

clean_shell_history() {
    [[ "${CLEAN_SHELL_HISTORY}" != true ]] && return 0
    log_info "Removendo históricos de comandos do shell..."

    local history_files=(
        "${HOME}/.shell_alias"
        "${HOME}/.shell_config"
        "${HOME}/.bash_history"
        "${HOME}/.zsh_history"
        "${HOME}/.lesshst"
        "${HOME}/.python_history"
        "${HOME}/.node_repl_history"
        "${HOME}/.mysql_history"
        "${HOME}/.psql_history"
        "${HOME}/.sqlite_history"
        "${HOME}/.viminfo"
        "${HOME}/.local/share/nvim"
    )

    remove_all "${history_files[@]}"

    # 'history -c' aqui só afetaria este subshell. O terminal que invocou o
    # script mantém o histórico em memória e reescreve ~/.bash_history no
    # logout, desfazendo a remoção acima. Só o usuário pode evitar isso.
    if [[ "${DRY_RUN}" != true ]]; then
        log_warn "O histórico deste terminal ainda está em memória e será regravado no logout."
        log_warn "Execute NESTE terminal ao final: unset HISTFILE && exit"
    fi
}

# --- ORQUESTRADOR PRINCIPAL ---

run_protocol() {
    echo -e "${COLOR_CYAN}=====================================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}              INICIANDO EXIT PROTOCOL                ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}=====================================================${COLOR_RESET}"
    echo "Usuário alvo: ${USER} (${HOME})"
    echo "Modo Dry-Run: ${DRY_RUN}"
    echo

    kill_running_processes

    clean_browsers
    clean_dev_credentials
    clean_cloud_infra
    clean_dev_tokens
    clean_ides
    clean_communication
    clean_user_dirs
    clean_custom_paths
    clean_trash
    clean_shell_history

    echo
    echo -e "${COLOR_GREEN}=====================================================${COLOR_RESET}"
    if [[ "${DRY_RUN}" == true ]]; then
        echo -e "${COLOR_YELLOW}     SIMULAÇÃO CONCLUÍDA (--dry-run)                 ${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}  Nenhum arquivo ou dado real foi modificado.        ${COLOR_RESET}"
    elif [[ "${FAILED_COUNT}" -gt 0 ]]; then
        echo -e "${COLOR_RED}     EXIT PROTOCOL CONCLUÍDO COM FALHAS               ${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}     EXIT PROTOCOL CONCLUÍDO COM SUCESSO!            ${COLOR_RESET}"
        echo -e "${COLOR_GREEN}  Recomenda-se fechar este terminal ou fazer logout. ${COLOR_RESET}"
    fi
    echo -e "${COLOR_GREEN}=====================================================${COLOR_RESET}"

    if [[ "${FAILED_COUNT}" -gt 0 ]]; then
        echo
        log_error "${FAILED_COUNT} item(ns) não puderam ser removidos ou foram bloqueados."
        log_error "Revise as linhas [ERRO] acima: esses dados AINDA ESTÃO na máquina."
        return 1
    fi
}

show_help() {
    cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Script seguro para higienização e desligamento/offboarding no Ubuntu Linux.

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
    run_protocol
fi
