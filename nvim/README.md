# Neovim AIDLC — configuração Windows

Configuração LazyVim adaptada da especificação AIDLC. O computador atual é Windows 11 x64 (não macOS/Apple Silicon), por isso comandos Homebrew, OrbStack e alguns TUIs exclusivos de macOS não foram executados.

## Iniciar

Feche e reabra o terminal para recarregar o `PATH` atualizado pelo winget. Depois, abra PowerShell no diretório raiz do repositório (monorepo) e execute `nvim`. As 11 abas são criadas com `tcd` local. Na primeira configuração, `notes`, `frontend` e `backend/database` não existiam em `C:\Users\EcomTech`; suas abas apontaram para a raiz, sem criar pastas. Confirme o root e ajuste os caminhos em `lua/config/workspaces.lua`; qualquer caminho ausente continuará apontando para a raiz.

Para abrir outro serviço em uma aba isolada:

```vim
:NewTabProject "C:\caminho\para\servico" "Nome do servico" "AWS_PROFILE=dev;ASPNETCORE_ENVIRONMENT=Development"
```

O terceiro argumento é opcional. Sem argumentos, `:NewTabProject` pergunta caminho, nome e ambiente. Variáveis definidas assim são entregues apenas aos terminais daquela aba; valores de ambiente de abas dinâmicas não são gravados no arquivo de sessão. Não passe senhas na linha de comando, pois elas podem ficar no histórico do editor.

As sessões do LazyVim (`<leader>qs`, `<leader>ql`, `<leader>qS`) preservam abas e diretórios. Os nomes são mantidos num JSON local em `stdpath(state)`; ambientes dinâmicos não são salvos. Terminais não sobrevivem ao fechamento do Neovim. Para Claude Code/Aider de longa duração, instale `tmux` no WSL e anexe a sessão no terminal da aba.

## Abas iniciais

`Notes`, `FrontEnd`, `Backend`, `AI Harness`, `Database`, `Cache`, `Containers`, `Git`, `API`, `Cloud`, `Logs`. O terminal shell comum só inicia ao pressionar `<C-\\>`; Claude Code e TUIs configurados iniciam quando a respectiva aba é visitada pela primeira vez. `Cloud` usa `AWS_PROFILE=dev` e `AZURE_CONFIG_DIR=~/.azure-dev`; ajuste esses valores em `lua/config/workspaces.lua`. O nome da aba mostra a assinatura Azure em cache, atualizada ao entrar nela.

## Dependências

Neovim 0.12.5 foi instalado via `winget`. Git, Node.js/npm, .NET SDK 10, GitHub CLI, AWS CLI e Docker já estavam detectáveis. Instalei também `ripgrep`, `fd`, `lazygit`, `lazydocker`, Azure CLI, Bruno CLI (`bru` 4.2.1) e GCC/WinLibs. `lazygit` foi instalado, mas o Windows Device Guard bloqueou sua execução tanto diretamente quanto via `cmd.exe`; não tentei contornar essa política. O TUI `lazyredis` não tem pacote Windows configurado; a aba Cache usa `redis-cli` se estiver disponível. O primeiro início baixa Lazy.nvim, LazyVim e os plugins. LSPs e depuradores são geridos pelo Mason; execute `:Mason` para conferir instalações e `:checkhealth` para diagnóstico.

A política Windows Device Guard bloqueia tanto o `tree-sitter.exe` baixado pelo Mason quanto o `lazygit.exe`. Para evitar erros repetidos, Tree-sitter e o plugin de renderização inline Markdown estão temporariamente desativados; Neovim usa realce nativo por tipo de arquivo e o preview Markdown no navegador continua disponível. Não tentei contornar a política. Para reativá-los, peça ao administrador/IT para permitir os executáveis aprovados, remova os três itens `enabled = false` de `lua/plugins/ui.lua` e rode `:TSUpdate`.

Ferramentas e autenticação:

- Instaladas via winget: `BurntSushi.ripgrep.MSVC`, `sharkdp.fd`, `JesseDuffield.lazygit`, `JesseDuffield.Lazydocker`, `Microsoft.AzureCLI`.
- Bruno CLI instalado com `npm install -g @usebruno/cli`; o comando `bru --version` foi verificado.
- Para nuvem, faça login manualmente quando necessário: `aws sso login` e `az login`. A aba Cloud usa `AWS_PROFILE=dev` e `AZURE_CONFIG_DIR=~/.azure-dev`; nenhuma credencial foi criada ou copiada.
- `gh auth login` para Octo.nvim. CSharpier e ferramentas de linguagem são geridos pelo Mason.
- `lazyredis` não é suportado por este setup Windows; instale `redis-cli` se precisar da alternativa. Nenhuma senha/conexão foi configurada.

O terminal usa o shell padrão do Neovim (`cmd.exe` neste Windows). Ferramentas ausentes não impedem abrir o editor; verifique `:Mason` e `:checkhealth` para diagnóstico.

> TODO: confirmar os nomes reais das pastas no monorepo, AWS profile, runner Angular (Jest/Vitest/Karma) e uso de Terraform/Bicep/CDK. Bicep/Terraform não foram habilitados por padrão. Karma deve ser executado no terminal.

## Problemas encontrados nesta instalação — guia para a próxima

1. **O alvo da especificação não corresponde ao PC.** A especificação presume macOS/Apple Silicon e Homebrew; o equipamento é Windows 11 x64. Não copie comandos `brew`, OrbStack ou pressupostos de caminhos Unix. Primeiro confirme SO, arquitetura, terminal e shell; use os pacotes Windows correspondentes. `lazyredis` não tem instalação Windows configurada, portanto o código tenta `redis-cli` como alternativa.
2. **`nvim` não apareceu no terminal que já estava aberto.** O `winget` adicionou Neovim ao `PATH` do sistema, mas processos de terminal antigos mantêm o ambiente anterior. Feche/reabra PowerShell/Windows Terminal (ou faça logoff/login) antes de diagnosticar como falha de instalação.
3. **Diretórios de workspace presumidos não existiam.** No diretório usado no primeiro teste faltavam `notes`, `frontend` e `backend/database`; não criar diretórios dentro de um repositório sem autorização. O inicializador mantém as abas, aponta caminhos faltantes para a raiz e avisa. Rode `nvim` na raiz correta do monorepo e confirme/edite a tabela `M.definitions`.
4. **APIs de Neovim presumidas não estavam disponíveis.** `vim.fs.isabs` e `vim.api.nvim_tabpage_call` falharam neste build Windows. A configuração usa um teste explícito de caminho absoluto Windows (`C:\...`/UNC/`/...`) e troca temporariamente para a tab-alvo com `nvim_set_current_tabpage`, restaurando a tab original depois. Ao portar para outra versão/build, valide as APIs antes de usá-las.
5. **A inicialização de tabs parecia não funcionar em teste headless.** LazyVim carrega a configuração do usuário em `VeryLazy`, que pode ocorrer depois de `VimEnter`; registrar somente um autocmd `VimEnter` perdeu o evento. `workspaces.setup()` agora agenda `M.initialize()` diretamente. Headless também não simula uma entrada normal na UI: para teste reproduzível, dispare `User VeryLazy` manualmente e espere o scheduler:

   ```vim
   nvim --headless -c 'doautocmd User VeryLazy' -c 'lua vim.wait(3000); print("tabs=" .. vim.fn.tabpagenr("$"))' -c 'qa!'
   ```

   O resultado esperado sem argumentos é `tabs=11`. Abrir Neovim com arquivos/argumentos intencionalmente não cria a grade de workspaces.
6. **Fechar Neovim cedo abortou downloads do Mason.** O primeiro início mostrou instalações em andamento e o encerramento as terminou. Na primeira abertura real, deixe Lazy/LSP/Mason concluir antes de sair; confira `:Mason` e `:Lazy`. Não conclua que uma ferramenta falhou só porque não estava instalada após interromper o primeiro processo.
7. **Windows Device Guard bloqueia executáveis legítimos.** Mesmo após baixar e validar o hash via Mason/winget, a política bloqueou `tree-sitter.exe` e `lazygit.exe`. O GCC/WinLibs está disponível, mas não resolve o bloqueio da política. Não mova, renomeie nem tente contornar os binários. Tree-sitter e `render-markdown.nvim` estão desativados para evitar erros; o markdown-preview no navegador continua funcionando. `lazygit` está instalado, mas a aba Git pode não iniciar seu TUI até IT/admin aprovar o executável. Só reative Tree-sitter após aprovação, removendo os três `enabled = false` em `lua/plugins/ui.lua` e executando `:TSUpdate`.
8. **Markdown do Neovim 0.12 tenta iniciar Tree-sitter no runtime.** O `ftplugin/markdown.lua` incluído no Neovim chama `vim.treesitter.start()` incondicionalmente e produziu erro sem parser. `config/options.lua` captura apenas o erro “Parser could not be created” e deixa o realce nativo funcionar; não remova esse fallback enquanto o parser estiver bloqueado.
9. **Azure CLI no Windows é um `.cmd`, não um executável nativo.** `vim.system({ "az", ... })` não é confiável no libuv do Windows. O statusline agora chama `cmd.exe /c az ...`; isso também evita executar `az` em cada redraw. O teste não fez login nem criou credenciais.
10. **Avisos do npm durante a instalação do Bruno CLI.** `npm install -g @usebruno/cli` avisou que o script pós-instalação de `protobufjs` não foi autorizado pela configuração `allow-scripts`, além de dependências deprecated. `bru --version` retornou `4.2.1`; não autorizei scripts adicionais sem necessidade.
11. **Não confunda instalação com autenticação.** Azure CLI, AWS CLI e GitHub CLI foram verificados/instalados, mas nenhum login foi feito. Configure `az login`, `aws sso login` e `gh auth login` apenas com as contas/perfis corretos; nunca grave credenciais no `README` ou no repositório.
12. **Valide Lua antes de reiniciar o editor.** Um erro de sintaxe Lua apareceu durante o primeiro ciclo de ajustes e foi corrigido. Após alterações, use `loadfile()` nos arquivos em `lua/`/`ftplugin/`, depois teste tabs, mapas e abertura de Markdown; faça um teste interativo também, pois headless não cobre todos os eventos da UI.

### Checklist de uma nova instalação

- [ ] Confirmar SO/arquitetura, versão de Neovim e raiz real do repositório antes de gerar a configuração.
- [ ] Confirmar política corporativa para binários baixados; não tentar contorná-la.
- [ ] Instalar Neovim e ferramentas aprovadas; reabrir o terminal para atualizar o `PATH`.
- [ ] Ajustar as pastas e variáveis de workspace em `lua/config/workspaces.lua` sem criar pastas ou inserir segredos.
- [ ] Validar todos os arquivos Lua; iniciar Neovim uma vez e aguardar instalações de plugins/Mason terminarem.
- [ ] Testar a inicialização de 11 tabs, mappings de terminal/Explorer/Markdown e workspace dinâmico; conferir `:Lazy`, `:Mason` e `:checkhealth`.
- [ ] Só então configurar autenticação interativamente e testar comandos de nuvem no perfil/subscription esperado.

## Mapeamentos principais

- `gt` / `gT`, `1gt` ... `11gt`: navegação nativa entre abas.
- `<leader><tab>n`: novo projeto; `<leader><tab>0` / `<leader><tab>$`: mover ao início/fim.
- `<A-Right>` / `<A-Left>`: mover aba; requer Alt/Meta encaminhado pelo terminal.
- `<C-\\>`: terminal shell exclusivo da aba atual.
- `<Esc><Esc>` no terminal: voltar ao modo normal; `<C-h/j/k/l>`: navegar entre janelas.
- `<leader>e`: Neo-tree; `<leader>D`: Dadbod UI.
- `<leader>yp`, `<leader>yr`, `<leader>yl`, `<leader>ya`: copiar caminho absoluto, relativo, caminho:linha(s), ou `@caminho` para clipboard.
- `<leader>cp` em Markdown: preview no navegador (Mermaid e outros diagramas).
- `<leader>ac`, `<leader>af`, `<leader>as`: Claude Code; `<leader>od`: abrir Datadog.
- `:WorkspaceCommand`: repetir o comando configurado para a aba atual.

Não foram mapeados `<Tab>`, `]t`, `[t`, `<leader>t` nem `<leader>w`. O atalho LazyVim do terminal Snacks `<C-/>` foi desativado; o terminal Snacks em si não é usado.
