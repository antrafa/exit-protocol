# Protocolo de Demissão 🛡️
> Higienização rápida, segura e auditável de estações de trabalho Ubuntu Linux.

O **Protocolo de Demissão** é um utilitário em Bash desenvolvido para automatizar a remoção completa de credenciais pessoais, tokens corporativos, históricos de comando, perfis de navegadores, sessões de aplicativos de comunicação e repositórios locais antes da devolução de um computador ou desligamento de um projeto.

---

## 🎯 Por Que Este Script Existe?

Ao devolver uma máquina corporativa com Ubuntu/Linux ou encerrar um contrato de trabalho, desenvolvedores e profissionais de TI frequentemente deixam para trás:

- **Tokens e Chaves de Infraestrutura:** AWS, Google Cloud, Azure, clusters Kubernetes (`~/.kube`), credenciais Docker e Vault.
- **Chaves Privadas e Assinaturas:** Chaves SSH (`~/.ssh`) e chaves GPG (`~/.gnupg`).
- **Navegadores Pessoais e Corporativos:** Histórico de navegação, e-mails sincronizados, senhas salvas e cookies de sessão (Google Chrome, Chromium, Firefox, Brave, Edge).
- **Gerenciadores de Pacotes:** Tokens e segredos no `.npmrc`, `.pypirc`, Cargo, Composer, Maven, Gradle e `.netrc`.
- **Comunicação:** Sessões ativas de Slack, Discord, Microsoft Teams e Telegram.
- **Históricos de Terminal:** Comandos com senhas em texto puro, tokens de API ou IPs corporativos em `.bash_history` ou `.zsh_history`.
- **Arquivos Pessoais:** Arquivos salvos em `Downloads`, `Documentos`, `Desktop` e `Lixeira`.

Fazer essa limpeza manualmente é moroso e sujeito a esquecimentos. Por outro lado, comandos manuais mal planejados (`rm -rf`) trazem risco de corrupção ou travamento do sistema.

O **Protocolo de Demissão** orquestra essa limpeza de ponta a ponta com salvaguardas de segurança rigorosas, execução com simulação (*dry-run*) e confirmação explícita.

---

## 📋 Pré-requisitos

1. **Sistema Operacional:** Ubuntu Linux (versões 20.04 LTS, 22.04 LTS, 24.04 LTS ou derivados Debian).
2. **Interpretador:** Bash (versão 4.0 ou superior).
3. **Privilégios:** **Executar como usuário comum**. 
   > ⚠️ **NUNCA execute este script com `sudo` ou como usuário `root`!**  
   > O script limpa o `$HOME` do usuário que o invoca. Rodar como root não apagará seus dados pessoais e poderá danificar arquivos do administrador. O script possui uma trava de segurança que aborta imediatamente se invocado como root.

---

## 🛡️ Mecanismos de Salvaguarda e Segurança

O script foi concebido com uma política rígida de tolerância zero a falhas destrutivas:

- **Bloqueio de Root (`check_not_root`):** O script verifica o `EUID` e encerra a execução com código de erro se for rodado como root ou via `sudo`.
- **Lista Negra de Diretórios Críticos:** Bloqueio explícito contra remoção de `/`, `/home`, `/root`, `/bin`, `/boot`, `/dev`, `/etc`, `/lib`, `/usr`, `/var`, `/tmp`, etc.
- **Proteção do `$HOME`:** Impede qualquer chamada acidental que tente deletar a raiz do diretório home do usuário.
- **Normalização de Caminhos:** Remove barras redundantes e trata caminhos entre aspas para evitar problemas com espaços ou caracteres especiais.
- **Suporte a Links Simbólicos Quebrados:** Identifica e remove symlinks inválidos sem falhas de verificação de existência (`-e` vs `-L`).
- **Preservação de Pastas do Sistema:** Em pastas como `Downloads/`, `Documentos/` e `Lixeira`, o script **apaga apenas o conteúdo interno**, preservando a pasta em si para manter a integridade visual da interface gráfica do Ubuntu.
- **Confirmação Explícita:** Por padrão, a execução real só inicia após o usuário digitar exatamente a palavra `CONFIRMAR`.

---

## 🚀 Guia de Uso

### 1. Dar Permissão de Execução

Torne o script executável:
```bash
chmod +x protocolo-demissao.sh
```

---

### 2. Simulação / Dry-Run (Altamente Recomendado)

Antes de apagar qualquer arquivo, execute o modo de simulação. Ele analisa o sistema e lista exatamente o que seria removido ou esvaziado, mostrando tamanhos estimados e arquivos não encontrados, sem alterar nada:

```bash
./protocolo-demissao.sh --dry-run
```

Exemplo de saída do dry-run:
```text
[INFO] Modo de simulação ativo (--dry-run). NENHUM arquivo será modificado.
=====================================================
       INICIANDO PROTOCOLO DE DEMISSÃO               
=====================================================
Usuário alvo: antoniorafael (/home/antoniorafael)
Modo Dry-Run: true

[DRY-RUN] Simulação: encerraria processos de navegadores e aplicativos
[INFO] Limpando navegadores (histórico, perfis, cache e cookies)...
[DRY-RUN] Removeria: /home/antoniorafael/.config/google-chrome (1.2G)
[DRY-RUN] Removeria: /home/antoniorafael/.mozilla (850M)
[IGNORADO] Não encontrado: /home/antoniorafael/snap/chromium
...
=====================================================
     SIMULAÇÃO CONCLUÍDA (--dry-run)                 
  Nenhum arquivo ou dado real foi modificado.        
=====================================================
```

---

### 3. Execução Real (Modo Interativo com Confirmação)

Para executar a higienização de fato:

```bash
./protocolo-demissao.sh
```

O script exibirá um aviso em vermelho e solicitará uma confirmação digitada:
```text
============================== ATENÇÃO ==============================
Este script apagará dados de histórico, credenciais e pastas configuradas!
Essa ação é irreversível.
=====================================================================

Para confirmar a execução, digite exatamente 'CONFIRMAR': 
```

- Se você digitar `CONFIRMAR`, o processo de higienização será iniciado.
- Se você digitar qualquer outra coisa ou pressionar `Enter`, o script cancelará a execução imediatamente sem alterar arquivos.

---

### 4. Execução Não-Interativa (`--force`)

Para uso automatizado por equipes de TI, scripts de desprovisionamento ou rotinas sem prompt interativo:

```bash
./protocolo-demissao.sh --force
```

> ⚠️ **Atenção:** A flag `--force` ignora a pergunta de confirmação e executa a remoção imediatamente. Utilize apenas quando tiver total certeza da configuração.

---

### 5. Ajuda

Para ver as opções disponíveis via linha de comando:

```bash
./protocolo-demissao.sh --help
```

---

## ⚙️ Configuração e Personalização

No topo do arquivo `protocolo-demissao.sh`, você encontra as flags que ligam ou desligam cada módulo de limpeza e a lista de pastas customizadas:

```bash
# --- CONFIGURAÇÃO DE ATIVAÇÃO DOS MÓDULOS ---
CLEAN_BROWSERS=true          # Google Chrome, Chromium, Firefox, Brave, Edge, Opera, Vivaldi
CLEAN_DEV_CREDENTIALS=true   # SSH, GPG, Git configs e tokens em cache
CLEAN_CLOUD_INFRA=true       # AWS, GCP, Azure, Kubernetes, Docker, Terraform, Vault
CLEAN_DEV_TOKENS=true        # npm, pip, cargo, composer, gradle, maven, .netrc
CLEAN_IDES=true              # VS Code, JetBrains, Cursor, VSCodium
CLEAN_COMMUNICATION=true     # Slack, Discord, Microsoft Teams, Telegram
CLEAN_USER_DIRS=true         # Downloads, Documentos, Desktop, Imagens, Vídeos, Música
CLEAN_SHELL_HISTORY=true     # .bash_history, .zsh_history, histórico de comandos e DBs
CLEAN_TRASH=true             # Lixeira do Ubuntu (~/.local/share/Trash)

# --- PASTAS CUSTOMIZADAS ---
CUSTOM_PATHS=(
    # "$HOME/projetos"
    # "$HOME/workspace"
    # "~/meus_repos"
)
```

### Como Adicionar Pastas Customizadas (`CUSTOM_PATHS`)
Se você guarda projetos, repositórios ou pastas de trabalho em diretórios específicos fora do padrão, descomente ou adicione-os no array `CUSTOM_PATHS`:

```bash
CUSTOM_PATHS=(
    "$HOME/projetos"
    "$HOME/workspace"
    "$HOME/Documents/work"
    "~/repos"
)
```

- Suporta tanto `$HOME` quanto o caractere de expansão de til `~`.
- Pastas configuradas aqui serão completamente excluídas (`rm -rf`).

---

## 🗂️ Mapeamento Detalhado dos Módulos e Alvos

| Módulo | Ativador | O que é limpo / Alvos |
| :--- | :--- | :--- |
| **Encerramento de Processos** | Automático | Executa `pkill` para fechar navegadores e mensageiros antes de apagar arquivos de banco e sessão. |
| **Navegadores** | `CLEAN_BROWSERS` | Perfis, caches, senhas e histórico (.deb, Snap e Flatpak):<br>• Google Chrome / Chromium (`.config`, `.cache`, `snap`, `.var/app`)<br>• Mozilla Firefox (`.mozilla`, `.cache/mozilla`, `snap`, `.var/app`)<br>• Brave Browser (`.config/BraveSoftware`, `snap`, `.var/app`)<br>• Microsoft Edge (`.config/microsoft-edge`, `snap`, `.var/app`)<br>• Opera e Vivaldi (`.config/opera`, `.config/vivaldi`) |
| **Credenciais Dev** | `CLEAN_DEV_CREDENTIALS` | • Chaves e hosts SSH (`~/.ssh`)<br>• Chaves GPG/PGP (`~/.gnupg`)<br>• Configuração e credenciais Git (`~/.gitconfig`, `~/.git-credentials`, `~/.config/git`)<br>• Esvazia cache de credenciais do Git em memória (`git credential-cache exit`) |
| **Nuvem & DevOps** | `CLEAN_CLOUD_INFRA` | • AWS CLI (`~/.aws`)<br>• Google Cloud SDK (`~/.config/gcloud`)<br>• Azure CLI (`~/.azure`)<br>• Kubernetes / K9s (`~/.kube`, `~/.minikube`, `~/.k9s`)<br>• Docker config e tokens de auth (`~/.docker`)<br>• Terraform (`~/.terraform.d`, `~/.terraformrc`)<br>• Helm charts e caches (`~/.config/helm`, `~/.cache/helm`)<br>• HashiCorp Vault token (`~/.vault-token`) |
| **Tokens de Pacotes** | `CLEAN_DEV_TOKENS` | • Node / JS: `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, `~/.config/pnpm`<br>• Python: `~/.pip/pip.conf`, `~/.pypirc`<br>• Rust: `~/.cargo/credentials`, `credentials.toml`<br>• PHP: `~/.composer/auth.json`, `~/.config/composer/auth.json`<br>• Java: `~/.m2/settings.xml`, `settings-security.xml`, `~/.gradle/gradle.properties`<br>• Geral: `~/.netrc` |
| **IDEs e Editores** | `CLEAN_IDES` | • VS Code e VSCodium: workspaces, históricos, backups e extensões (`~/.config/Code`, `~/.vscode`, `snap/code`, `.config/VSCodium`)<br>• Cursor AI: `~/.cursor`, `~/.config/Cursor`<br>• Família JetBrains: IntelliJ, PyCharm, WebStorm, etc. (`.config/JetBrains`, `.local/share/JetBrains`, `.cache/JetBrains`) |
| **Comunicação** | `CLEAN_COMMUNICATION` | Sessões, caches e dados locais (.deb, Snap e Flatpak):<br>• Slack (`~/.config/Slack`, `.cache`, `snap`, `.var/app`)<br>• Discord (`~/.config/discord`, `snap`, `.var/app`)<br>• Microsoft Teams (`~/.config/teams`, `~/.config/Microsoft/...`, `.var/app`)<br>• Telegram Desktop (`~/.local/share/TelegramDesktop`, `snap`, `.var/app`) |
| **Pastas de Usuário** | `CLEAN_USER_DIRS` | Esvazia o **conteúdo interno** mantendo as pastas estruturais:<br>• `Downloads/`<br>• `Documents/` e `Documentos/`<br>• `Desktop/` e `Área de Trabalho/`<br>• `Pictures/` e `Imagens/`<br>• `Videos/` e `Vídeos/`<br>• `Music/` e `Música/` |
| **Pastas Customizadas** | `CUSTOM_PATHS` | Remove recursivamente todos os diretórios e arquivos listados no array `CUSTOM_PATHS`. |
| **Lixeira** | `CLEAN_TRASH` | Esvazia todos os arquivos da lixeira do usuário em `~/.local/share/Trash`. |
| **Histórico de Shell** | `CLEAN_SHELL_HISTORY` | • Históricos de shell: `~/.bash_history`, `~/.zsh_history`<br>• Históricos de pagers e REPLs: `.lesshst`, `.python_history`, `.node_repl_history`<br>• Históricos de bancos de dados: `.mysql_history`, `.psql_history`, `.sqlite_history`<br>• Históricos de editores: `.viminfo`, `.local/share/nvim`<br>• Limpa histórico em memória da sessão atual com `history -c` e `history -w`. |

---

## 🔒 Cuidados Finais e Pós-Execução

Ao concluir a execução do script:

1. **Feche o terminal imediatamente ou faça Logout:**  
   Alguns shells (como o Bash ou Zsh) mantêm buffers de comandos executados na sessão corrente em memória RAM e os escrevem de volta no arquivo de histórico quando o terminal é fechado normalmente. Embora o script execute `history -c`, a melhor prática recomendada é fechar a janela do terminal ou encerrar a sessão do usuário (`gnome-session-quit` ou reiniciar o computador).
2. **Revogue Tokens em Servidores Remotos:**  
   Lembre-se de revogar chaves e acessos nos serviços remotos (GitHub, GitLab, AWS IAM Console, GCP Console, VPNs corporativas), pois apagar o token local encerra apenas o arquivo físico da máquina.

---

## 🧪 Suíte de Testes Automatizados

O projeto conta com uma suíte abrangente de testes unitários e de integração utilizando sandboxes temporários isolados para garantir que nenhuma deleção ocorra fora do escopo ou em caminhos proibidos.

### Como Executar Todos os Testes

```bash
./tests/run_all_tests.sh
```

A suíte consolidada executa em sequência:
1. `tests/test_safety.sh`: Valida proteção contra execução como root, bloqueio da raiz `/`, bloqueio de caminho vazio, proteção de `$HOME` e deleção de symlinks quebrados.
2. `tests/test_browsers.sh`: Valida encerramento simulado de processos e deleção seletiva de perfis de Chrome, Firefox, Brave e Edge tanto em `--dry-run` quanto em execução real.
3. `tests/test_credentials.sh`: Valida deleção segura de chaves SSH, configs de nuvem (AWS, Kube, Docker) e tokens de pacotes (.npmrc, .pypirc).
4. `tests/test_user_and_custom.sh`: Valida esvaziamento de conteúdo de diretórios mantendo as pastas de usuário, limpeza de histórico, lixeira e pastas customizadas em `CUSTOM_PATHS`.

Se todos os testes passarem, o script encerra com código `0` e exibe:
```text
---------------------------------------------------------------
TODOS OS TESTES PASSARAM COM SUCESSO!
```
