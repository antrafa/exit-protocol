# Design Doc: Protocolo de Demissão (Ubuntu Linux)

- **Data:** 2026-09-18
- **Autor:** Open Source Contributor
- **Status:** Aprovado para Implementação
- **Alvo:** Ubuntu Linux (Desktop / Workstation)

---

## 1. Visão Geral

O **Protocolo de Demissão** é um script bash autocontido, seguro e modular projetado para higienização e limpeza de máquinas corporativas com Ubuntu Linux antes da devolução do equipamento ou término de contrato.

O script permite a remoção estruturada de rastros pessoais, credenciais confidenciais de desenvolvedor, acessos a nuvens/infraestrutura, sessões de aplicativos de comunicação, históricos e perfis de navegadores, além de pastas pessoais e diretórios customizáveis indicados pelo usuário.

---

## 2. Objetivos e Não-Objetivos

### Objetivos
- **Autocontido e Portátil:** Funcionar em um único arquivo bash executável (`protocolo-demissao.sh`), utilizando apenas utilitários padrão do Ubuntu (`bash`, `coreutils`, `find`, `pkill`/`killall`), sem dependências externas.
- **Segurança Rigorosa:** 
  - Bloquear execução via `sudo`/`root` para evitar que o `$HOME` aponte para `/root` ou que diretórios de sistema sejam corrompidos.
  - Validar e sanitizar todos os caminhos antes de `rm -rf`, bloqueando exclusões de caminhos perigosos como `/`, `/home`, `/usr`, etc.
  - Suportar modo `--dry-run` para simular as exclusões sem apagar nenhum dado real.
  - Exigir confirmação manual explícita digitando `CONFIRMAR` (a menos que a flag `--force` seja informada).
- **Cobertura Abrangente:** Lidar com pacotes nativos (`apt`), **Snap** e **Flatpak**, comuns nas distribuições modernas do Ubuntu.
- **Customização Simples:** Bloco de configuração declarativo no topo do arquivo com toggles booleanos e uma lista de caminhos customizados `CUSTOM_PATHS`.
- **Preservação do Sistema Operacional:** Esvaziar o conteúdo de pastas padrão (`~/Downloads/*`, `~/Documents/*`), mantendo os diretórios-raiz intactos para evitar erros no GNOME e XDG.

### Não-Objetivos
- Não realiza formatação de disco ou sobrescrita com `shred`/`dd` (foco em remoção de sessões, dados e credenciais a nível de usuário).
- Não remove pacotes de software do sistema (o objetivo é limpar dados e sessões do usuário, não desinstalar ferramentas).
- Não suporta macOS ou Windows neste estágio (escopo exclusivo para Ubuntu Linux conforme definido).

---

## 3. Arquitetura e Configuração

### 3.1 Bloco de Configuração (Topo do Script)

O script expõe variáveis declarativas para controle modular:

```bash
# ==============================================================================
# CONFIGURAÇÃO DO PROTOCOLO DE DEMISSÃO
# ==============================================================================

# Ativação dos módulos de limpeza (true / false)
CLEAN_BROWSERS=true          # Google Chrome, Chromium, Firefox, Brave, Edge
CLEAN_DEV_CREDENTIALS=true   # SSH (~/.ssh), GPG (~/.gnupg), Git (.gitconfig, .git-credentials)
CLEAN_CLOUD_INFRA=true       # AWS, GCP, Azure, Kubernetes (~/.kube), Docker (~/.docker)
CLEAN_DEV_TOKENS=true        # npm, pip, cargo, composer, gradle, maven, .netrc
CLEAN_IDES=true              # VS Code, JetBrains, Cursor (histórico, workspaces, sessões)
CLEAN_COMMUNICATION=true     # Slack, Discord, Microsoft Teams, Telegram
CLEAN_USER_DIRS=true         # Downloads, Documentos, Desktop, Imagens, Vídeos, Música
CLEAN_SHELL_HISTORY=true     # .bash_history, .zsh_history, histórico de comandos da sessão
CLEAN_TRASH=true             # Lixeira do Ubuntu (~/.local/share/Trash)

# Diretórios customizados para exclusão total (caminhos absolutos ou com $HOME)
CUSTOM_PATHS=(
    # "$HOME/projetos"
    # "$HOME/workspace"
    # "/var/tmp/meus_dados"
)
```

---

## 4. Mapeamento de Alvos por Módulo (Ubuntu)

### 4.1 Navegadores (`CLEAN_BROWSERS`)
*Ações prévias:* Encerramento suave de processos (`pkill -f` em `chrome`, `firefox`, `brave`, `edge`).
- **Google Chrome & Chromium:**
  - Nativo: `~/.config/google-chrome`, `~/.cache/google-chrome`, `~/.config/chromium`, `~/.cache/chromium`
  - Snap: `~/snap/chromium`, `~/snap/google-chrome`
  - Flatpak: `~/.var/app/com.google.Chrome`, `~/.var/app/org.chromium.Chromium`
- **Mozilla Firefox:**
  - Nativo: `~/.mozilla`, `~/.cache/mozilla`
  - Snap: `~/snap/firefox`
  - Flatpak: `~/.var/app/org.mozilla.firefox`
- **Brave & Edge:**
  - Nativo: `~/.config/BraveSoftware`, `~/.cache/BraveSoftware`, `~/.config/microsoft-edge`, `~/.cache/microsoft-edge`
  - Snap / Flatpak equivalentes.

### 4.2 Credenciais de Desenvolvimento & Git (`CLEAN_DEV_CREDENTIALS`)
- **SSH:** `~/.ssh`
- **GPG:** `~/.gnupg`
- **Git:** `~/.gitconfig`, `~/.git-credentials`, `~/.config/git`
- **Cache do Git:** Execução de `git credential-cache exit 2>/dev/null || true`.

### 4.3 Ferramentas de Nuvem & DevOps (`CLEAN_CLOUD_INFRA`)
- **Kubernetes:** `~/.kube`, `~/.minikube`, `~/.k9s`
- **Docker:** `~/.docker` (tokens de login em registries e credenciais)
- **AWS:** `~/.aws`
- **Google Cloud:** `~/.config/gcloud`
- **Azure:** `~/.azure`
- **Terraform / Helm:** `~/.terraform.d`, `~/.terraformrc`, `~/.config/helm`, `~/.cache/helm`

### 4.4 Tokens de Pacotes e Linguagens (`CLEAN_DEV_TOKENS`)
- **Node / JS:** `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, `~/.config/pnpm`
- **Python:** `~/.pip/pip.conf`, `~/.pypirc`
- **Rust:** `~/.cargo/credentials`, `~/.cargo/credentials.toml`
- **PHP:** `~/.composer/auth.json`, `~/.config/composer/auth.json`
- **JVM:** `~/.m2/settings.xml`, `~/.m2/settings-security.xml`, `~/.gradle/gradle.properties`
- **Geral:** `~/.netrc`

### 4.5 IDEs e Editores (`CLEAN_IDES`)
- **VS Code:** `~/.config/Code/User/workspaceStorage`, `~/.config/Code/User/history`, `~/.config/Code/Backups`, `~/.vscode`, `~/snap/code`
- **Cursor / VSCodium:** `~/.config/Cursor`, `~/.cursor`, `~/.config/VSCodium`
- **JetBrains:** `~/.config/JetBrains`, `~/.local/share/JetBrains`, `~/.cache/JetBrains`

### 4.6 Mensageiros e Comunicação (`CLEAN_COMMUNICATION`)
*Ações prévias:* `pkill -f` em `slack`, `discord`, `teams`, `telegram`.
- **Slack:** `~/.config/Slack`, `~/.cache/Slack`, `~/snap/slack`, Flatpak
- **Discord:** `~/.config/discord`, `~/snap/discord`, Flatpak
- **Microsoft Teams:** `~/.config/teams`, `~/.config/Microsoft/Microsoft Teams`, Flatpak
- **Telegram:** `~/.local/share/TelegramDesktop`, `~/snap/telegram-desktop`, Flatpak

### 4.7 Pastas Pessoais (`CLEAN_USER_DIRS`)
- Esvaziamento do conteúdo interno (sem remover o diretório pai):
  - `~/Downloads`
  - `~/Documents` (e `~/Documentos`)
  - `~/Desktop` (e `~/Área de Trabalho`)
  - `~/Pictures` (e `~/Imagens`)
  - `~/Videos` (e `~/Vídeos`)
  - `~/Music` (e `~/Música`)

### 4.8 Histórico de Terminal e Lixeira (`CLEAN_SHELL_HISTORY` & `CLEAN_TRASH`)
- **Arquivos:** `~/.bash_history`, `~/.zsh_history`, `~/.lesshst`, `~/.python_history`, `~/.node_repl_history`, `~/.viminfo`
- **Lixeira:** `~/.local/share/Trash/*`
- **Memória de Sessão:** `history -c && history -w` executado ao final da execução.

### 4.9 Pastas Customizadas (`CUSTOM_PATHS`)
- Remoção recursiva de todos os diretórios/arquivos listados no array `CUSTOM_PATHS`.

---

## 5. Medidas de Segurança e Mecânica de Execução

### 5.1 Bloqueio de Root
```bash
if [[ "${EUID}" -eq 0 ]]; then
    echo "ERRO: Não execute este script com sudo ou como root!"
    echo "Ele deve ser executado como o usuário comum que deseja limpar os dados."
    exit 1
fi
```

### 5.2 Validador `safe_remove`
Todo comando de remoção passará por uma função de validação:
- Verifica se a string do caminho não é vazia ou nula.
- Garante que não é `/`, `/home`, `/root`, `/bin`, `/boot`, `/dev`, `/etc`, `/lib`, `/usr`, `/var`, `/tmp`.
- Se `--dry-run` estiver ativo: apenas imprime `[DRY-RUN] Removeria: <caminho>` e calcula tamanho aproximado com `du -sh 2>/dev/null`.
- Se modo normal: executa `rm -rf -- "<caminho>"` e reporta `[OK] Removido: <caminho>`.

### 5.3 Interface CLI
- `./protocolo-demissao.sh`: Execução padrão com confirmação por teclado.
- `./protocolo-demissao.sh --dry-run`: Modo de simulação sem efeitos colaterais.
- `./protocolo-demissao.sh --force`: Pula o prompt de confirmação `CONFIRMAR`.
- `./protocolo-demissao.sh --help`: Exibe documentação de uso e opções.

---

## 6. Estratégia de Teste e Validação

1. **Teste de Dry-Run:** Executar `./protocolo-demissao.sh --dry-run` e verificar se a listagem respeita arquivos existentes sem alterar nada no disco.
2. **Teste em Ambiente Simulado:** Criar uma árvore de arquivos temporários representando `$HOME/Downloads/arquivo.txt`, `~/.test_custom/dummy`, `.gitconfig` falso, e testar a remoção seletiva.
3. **Teste de Failsafe:** Tentar passar `/` ou caminhos vazios para o `safe_remove` para garantir que o bloqueio funciona.
4. **Teste de Bloqueio Root:** Simular execução sob `EUID=0` para checar se aborta imediatamente.
