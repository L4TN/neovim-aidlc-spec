# Neovim as a Full-Cycle AI-Driven Development Lifecycle (AIDLC) IDE

A battle-tested specification for turning Neovim (LazyVim) into a complete, terminal-first IDE for **AI-driven development** — isolated workspaces per domain, per-tab terminals, lazy LSPs, and a CLI-only toolchain.

**Platform-agnostic by design.** Validated on **Windows 11 x64 / Neovim 0.12**; the macOS (Apple Silicon M4, 16 GB) path is fully specified below with its own install script. Linux follows the macOS path with the distro's package manager.

## The Generic Stack (and why)

| Layer | Choice | Why |
|-------|--------|-----|
| **Languages** | C# / .NET + TypeScript / Angular | Enterprise backend + SPA frontend is the most common enterprise pairing; both have strong LSP support (Roslyn, vtsls, angularls) |
| **Cloud** | AWS **and** Azure in one tab | Multi-cloud is reality; one tab with per-tab `env` (`AWS_PROFILE`, `AZURE_CONFIG_DIR`) keeps tenants isolated without tab sprawl |
| **Data** | Redis + SQL (vim-dadbod) | Query databases and inspect cache without leaving the keyboard; connection strings live in env vars, never in Git |
| **Containers** | Docker + lazydocker | TUI instead of Docker Desktop's GUI — lower RAM, fully keyboard-driven |
| **API testing** | Bruno CLI (`.bru` files) | Collections are **plain text and versioned in Git** (unlike Postman). The Electron app costs hundreds of MB; `bru run` costs nothing and is diff-able |
| **Git/GitHub** | lazygit + diffview + octo | Review diffs produced by AI agents, manage PRs/issues without a browser |
| **AI harness** | Claude Code / Aider in a persistent tab | The agent edits files while you review them in the editor; `autoread` + `checktime` keeps buffers fresh |
| **Notes** | Markdown + `markdown-preview.nvim` | Mermaid diagrams render live in the browser; the same fences render on GitHub, so notes and PRs stay consistent |

**The core idea:** in AI-driven development, the agent writes code, *you* review. Every tool choice optimizes for (1) minimal RAM, (2) zero mouse, (3) everything reviewable as plain text in version control.

## Architecture: isolated tab workspaces

Each Neovim tab is an isolated workspace: its own `tcd` (tab-local cwd), its own buffers (scope.nvim), its own toggleterm instance, optionally its own env vars. Nothing leaks across tabs.

All workspaces derive from a single root in `lua/config/workspaces.lua`:

```lua
local root = vim.fn.expand("~/source/repos/your-project")

M.definitions = {
  { name = "Notes",      path = root .. "/notes",             lazy = false },
  { name = "FrontEnd",   path = root .. "/frontend",          lazy = false },
  { name = "Backend",    path = root .. "/backend",           lazy = false },
  { name = "AI Harness", path = root, cmd = "claude",         lazy = true },
  { name = "Database",   path = root .. "/backend/database",  lazy = false },
  { name = "Cache",      path = root, cmd = "lazyredis",      lazy = true, fullscreen = true },
  { name = "Containers", path = root, cmd = "lazydocker",     lazy = true, fullscreen = true },
  { name = "Git",        path = root, cmd = "lazygit",        lazy = true, fullscreen = true },
  { name = "API",        path = root .. "/api",               lazy = false },
  { name = "Cloud",      path = root, lazy = true,
    env = { AWS_PROFILE = "dev", AZURE_CONFIG_DIR = vim.fn.expand("~/.azure-dev") } },
  { name = "Logs",       path = root, lazy = true },
}
```

- `lazy = true` → tab exists and is named at boot; its `cmd` runs on first visit only (TUIs and AI agents never eat RAM at startup).
- `env` → injected only into that tab's terminals; different cloud tenants per tab without global state.
- Dynamic microservice workspaces: `:NewTabProject <path> <name> [KEY=VAL;...]` (`<leader><tab>n`).
- Reach tab N natively with `Ngt` — tabs 10+ included.
- Workspace metadata (names, paths, cmds) persists per machine and is restored on session load; terminal processes do not survive restarts — run long AI sessions inside `tmux` and re-attach from the tab terminal.
- The Cloud tab shows the active AWS profile and the Azure subscription (resolved with `az account show`, **cached** — never called on every statusline redraw).

Measured result: **5/58 plugins loaded in 70ms** at boot; LSPs start only when a matching file opens.

## Keybindings

| Action | Key |
|--------|-----|
| Go to tab N | `Ngt` (native, incl. `10gt`, `11gt`) |
| New project tab | `<leader><tab>n` |
| Move tab | `<A-Right>` / `<A-Left>`; start/end `<leader><tab>0` / `<leader><tab>$` |
| Tab terminal | `<C-\>` (back: `<Esc><Esc>`; move: `<C-h/j/k/l>`) |
| Run tab's workspace command | `:WorkspaceCommand` (defined in `plugins/terminals.lua`) |
| Copy path (AI context) | `<leader>yp` absolute · `<leader>yr` relative · `<leader>yl` `path:line` · `<leader>ya` `@path` |
| Dadbod drawer | `<leader>D` |
| Markdown preview | `<leader>cp` |

LazyVim groups left untouched: `<leader>g` git, `<leader>d` DAP, `<leader>t` tests. Never mapped: `<Tab>` (jumplist), `]t`/`[t` (todo-comments), `<leader>t`/`<leader>w`.

## Configuration anatomy: layers, files and tabs

The full working configuration is versioned in this repo under [`nvim/`](./nvim) — copy it to `%LOCALAPPDATA%\nvim` (Windows) or `~/.config/nvim` (macOS/Linux) and start Neovim; Lazy.nvim bootstraps on first run.

The setup is built in stacked layers — each one only knows the layer below it:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 5 — External CLIs & TUIs (installed by the OS package manager)   │
│  lazygit · lazydocker · bru · az · aws · gh · claude · redis-cli · ng  │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 4 — Workspace/tab layer     nvim/lua/config/workspaces.lua       │
│  Declarative tab table (11 tabs) · :NewTabProject · native tabline     │
│  Per-tab env · lazy first-visit cmd · session metadata save/restore    │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 3 — Per-tab terminal layer  nvim/lua/config/terminals.lua        │
│  One toggleterm instance per tab, dir = tab tcd, env = tab env         │
│  + plugin spec: nvim/lua/plugins/terminals.lua  (toggleterm.nvim)      │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 2 — Tooling layer           nvim/lua/plugins/*.lua + Mason       │
│  lsp.lua · dap-test.lua · dadbod.lua · git.lua · ai.lua · ui.lua       │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 1 — Editor behavior         nvim/lua/config/*.lua                │
│  options.lua · keymaps.lua · autocmds.lua (autoread, tabline fn,       │
│  treesitter guard, .bru filetype, copy-path maps, Datadog opener)      │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 0 — Bootstrap              nvim/init.lua + lua/config/lazy.lua  │
│  lazy.nvim → LazyVim base + extras (neo-tree, angular, typescript,     │
│  dotnet, markdown, docker, yaml, eslint, dap-core)                     │
├─────────────────────────────────────────────────────────────────────────┤
│  Neovim 0.12 core (runtime, tree-sitter, LSP client, terminal jobs)    │
└─────────────────────────────────────────────────────────────────────────┘
```

```
nvim/                        ← the whole working config, versioned here
├── init.lua                 → Layer 0: bootstrap lazy.nvim
├── README.md                → machine-specific install record (Windows)
├── ftplugin/markdown.lua    → Layer 1: guard for the runtime's unconditional treesitter.start()
└── lua/
    ├── config/              → Layers 1–4 (behavior + workspaces)
    │   ├── lazy.lua         → Layer 0: lazy.nvim opts, LazyVim extras imports
    │   ├── options.lua      → Layer 1: autoread, showtabline, tabline function, .bru filetype
    │   ├── keymaps.lua      → Layer 1: <C-\>, copy-path group, tab moves, Datadog
    │   ├── autocmds.lua     → Layer 1: checktime on FocusGained/BufEnter/CursorHold/TermLeave
    │   ├── workspaces.lua   → Layer 4: the 11 tabs + :NewTabProject + tabline + cloud status
    │   └── terminals.lua    → Layer 3: per-tab shell + lazy workspace commands
    └── plugins/             → Layer 2 (one file per domain)
        ├── ui.lua           → neo-tree, scope.nvim, disabled snacks-explorer/bufferline
        ├── terminals.lua    → toggleterm.nvim spec
        ├── lsp.lua          → mason + roslyn.nvim + conform (csharpier, prettier)
        ├── dap-test.lua     → nvim-dap(-ui) + neotest adapters
        ├── dadbod.lua       → vim-dadbod(-ui/-completion)
        ├── git.lua          → diffview.nvim + octo.nvim
        └── ai.lua           → claudecode.nvim
```

### Where each tab lives in the code

| # | Tab | Defined in | Powered by |
|---|-----|-----------|------------|
| 1 | Notes | `config/workspaces.lua` `definitions[1]` (`notes`) | shell (Layer 3) + markdown-preview via markdown extra (`<leader>cp`) |
| 2 | FrontEnd | `definitions[2]` (`frontend`) | shell for `ng serve`; vtsls/angularls from `plugins/lsp.lua` |
| 3 | Backend | `definitions[3]` (`backend`) | shell for `dotnet watch run`; roslyn from `plugins/lsp.lua` |
| 4 | AI Harness | `definitions[4]` (`cmd = "claude"`, lazy) | `terminals.run_command` on first visit; claudecode.nvim (`plugins/ai.lua`) |
| 5 | Database | `definitions[5]` (`backend/database`) | dadbod-ui drawer `<leader>D` (`plugins/dadbod.lua`) |
| 6 | Cache | `definitions[6]` (`cmd = "lazyredis"`, lazy, fullscreen) | fallback chain in `config/terminals.lua`: `redis-cli` → warning |
| 7 | Containers | `definitions[7]` (`cmd = "lazydocker"`, lazy, fullscreen) | `terminals.run_command`; needs any Docker-API backend |
| 8 | Git | `definitions[8]` (`cmd = "lazygit"`, lazy, fullscreen) | `terminals.run_command`; diffview/octo (`plugins/git.lua`) |
| 9 | API | `definitions[9]` (`api`) | shell for `bru run`; `.bru` filetype from `config/options.lua` |
| 10 | Cloud | `definitions[10]` (`env = {AWS_PROFILE, AZURE_CONFIG_DIR}`) | per-tab env via Layer 3; subscription status cached by `workspaces.lua` (`cmd.exe /c az` on Windows) |
| 11 | Logs | `definitions[11]` | shell for log tailing; Datadog in browser via `keymaps.lua` (`<leader>od`) |
| + | any microservice | runtime: `:NewTabProject` (`keymaps.lua` `<leader><tab>n`) | same Layer 3/4 machinery as static tabs |

Adding a tab = one line in `M.definitions`; a dynamic tab needs no code at all.

## Plugin stack (Lazy.nvim / LazyVim)

- **UI:** neo-tree, native tabline reading `vim.t.tab_name` (plain text, no emojis), scope.nvim; snacks explorer and bufferline disabled
- **Terminal:** toggleterm.nvim, one instance per tab, scoped to the tab's `tcd`; Snacks terminal keymaps (`<C-/>`, `<C-_>`, `<leader>fT/ft`) removed after `User LazyVimKeymaps`
- **LSP (Mason):** roslyn.nvim (C#), vtsls + angularls, marksman, dockerls, docker_compose_language_service, yamlls + SchemaStore; bicep/terraformls only if the project uses IaC
- **Format/Lint:** conform.nvim (csharpier, prettier), ESLint, hadolint, actionlint
- **Debug/Test:** nvim-dap + nvim-dap-ui (netcoredbg, js-debug-adapter); neotest-dotnet + Jest/Vitest adapter (detect the runner from `package.json`; Karma runs in the terminal)
- **Git:** gitsigns, diffview.nvim, octo.nvim (needs an authenticated `gh`), lazygit
- **AI:** coder/claudecode.nvim (selection + diagnostics visible to the agent, diffs open in-editor); `autoread` + `:checktime` on FocusGained/BufEnter/CursorHold/TermLeave
- **Notes/API:** markdown-preview.nvim (`<leader>cp`, Mermaid/Chart.js in the browser), render-markdown.nvim, `.bru` filetype registered (plain text fallback)

## Dependencies (what actually gets installed)

| Tool | Role | macOS (Homebrew) | Windows (winget) |
|------|------|------------------|------------------|
| Neovim 0.12+ | editor | `neovim` | `Neovim.Neovim` |
| GCC / build tools | compile tree-sitter parsers | Xcode CLT (`xcode-select --install`) or `gcc` | `BrechtSanders.WinLibs.POSIX.UCRT` |
| ripgrep | search | `ripgrep` | `BurntSushi.ripgrep.MSVC` |
| fd | find | `fd` | `sharkdp.fd` |
| lazygit | Git tab | `lazygit` | `JesseDuffield.lazygit` |
| lazydocker | Containers tab | `lazydocker` | `JesseDuffield.Lazydocker` |
| Node.js + npm | Angular tooling, Bruno CLI | `node` (or nvm) | pre-installed (nvm4w) |
| .NET SDK 10 | C# backend, `csharpier` | `--cask dotnet-sdk` | pre-installed |
| GitHub CLI | octo.nvim, PRs | `gh` | pre-installed |
| AWS CLI | Cloud/Logs tabs | `awscli` | pre-installed |
| Azure CLI | Cloud/Logs tabs | `azure-cli` | `Microsoft.AzureCLI` |
| Bruno CLI | API tab (`bru run`) | `npm i -g @usebruno/cli` | `npm i -g @usebruno/cli` |
| lazyredis (optional) | Cache tab TUI | `brew tap sm010422/lazyredis && brew install lazyredis` (verify the tap before use) | no package — fallback: `redis-cli` or the vim-dadbod Redis adapter |
| tmux (optional) | persistent AI sessions | `tmux` | WSL |
| C# tooling | format/lint | Mason: roslyn, csharpier, fantomas | same |
| Docker runtime | Containers tab | OrbStack (recommended) or Colima — see below | Docker Desktop / WSL2 — see below |

## Installation scripts (per platform)

### macOS — Apple Silicon M4, 16 GB

```bash
# Build tools first — tree-sitter parsers need a C compiler
xcode-select --install

brew install neovim ripgrep fd lazygit lazydocker node gh awscli azure-cli tmux
brew install --cask dotnet-sdk

# Optional: Redis TUI (young project — verify the tap before trusting it)
brew tap sm010422/lazyredis && brew install lazyredis

# AI API client
npm install -g @usebruno/cli

# Lighter Docker runtime than Docker Desktop (recommended on 16 GB)
brew install --cask orbstack      # alternative: brew install colima docker

# Bruno CLI sanity check
bru --version
```

Then clone your monorepo, open Neovim at the root, and let Lazy.nvim bootstrap on first run (wait for Mason/Lazy to finish before quitting).

**macOS notes (expected behavior, not yet validated on hardware):**

- Default shell is `zsh`; Azure CLI installs as a native `az` binary — the Windows `cmd.exe` wrapper is skipped automatically (`has("win32")` guard).
- Terminal.app and default iTerm2 do **not** support the kitty keyboard protocol: keep `<C-\>` for the terminal toggle; `<C-'>` works only in Ghostty/kitty/WezTerm.
- `<A-Right>/<A-Left>` tab-move needs "Option as Meta" enabled in the terminal.
- 16 GB: avoid Docker Desktop (≈4 GB idle); OrbStack idles around 200 MB. `lazydocker` works with either backend.
- Inline diagrams in the terminal are deliberately excluded (needs kitty graphics protocol + headless Chromium); use the browser preview instead.

### Windows — x64 (validated configuration)

```powershell
# Editor + toolchain (exact winget IDs used and verified)
winget install --exact --id Neovim.Neovim --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id BrechtSanders.WinLibs.POSIX.UCRT --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id BurntSushi.ripgrep.MSVC --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id sharkdp.fd --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id JesseDuffield.lazygit --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id JesseDuffield.Lazydocker --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --exact --id Microsoft.AzureCLI --source winget --silent --accept-package-agreements --accept-source-agreements

# Bruno CLI
npm install -g @usebruno/cli
```

**Reopen the terminal after any `PATH` change** — existing processes keep stale env vars and `nvim` will look "not installed".

```powershell
# Post-install sanity check
nvim --version; rg --version; fd --version; lazygit --version; lazydocker --version
az version; bru --version

# Headless smoke test of the whole setup (expected: tabs=11)
nvim --headless -c 'doautocmd User VeryLazy' -c 'lua vim.wait(3000); print("tabs=" .. vim.fn.tabpagenr("$"))' -c 'qa!'
```

Inside Neovim: `:Lazy` (58 plugins), `:Mason`, `:checkhealth`, `:TSUpdate`.

## Windows-specific gotchas (learned the hard way)

1. **Smart App Control blocks unsigned binaries** (`tree-sitter.exe` from Mason, `lazygit.exe` from winget) *even when run from any shell with user approval*. Verify with a direct `--version` call before blaming your config. SAC was **irreversibly disabled** here via `VerifiedAndReputablePolicyState = 0` under `HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy` + reboot (requires admin; do not set it on a managed machine). After that, both binaries run.
2. **Neovim 0.12 rejects an empty `env` table in `termopen`** (`E475: Invalid argument: env`). Pass `env` only when it has keys, or toggleterm fails and you get a confusing cascade (`E21: modifiable is off`).
3. **Azure CLI is `az.cmd` on Windows** — `vim.system({"az"})` via libuv won't run it reliably. Use `cmd.exe /c` (the config guards this behind `has("win32")`) and cache the result; never call `az` on every statusline redraw.
4. **Default shell is `cmd.exe`**, not PowerShell — don't document PowerShell as the internal shell without configuring it.
5. **`vim.fs.isabs` and `nvim_tabpage_call` may not exist** in your build — validate every Neovim API against the installed version before using it.
6. **Neovim 0.12's Markdown ftplugin calls `treesitter.start()` unconditionally** — with parsers installed this is fine; on machines where the parser CLI is blocked, guard the "Parser could not be created" error or Markdown buffers throw on open.
7. **LazyVim loads user config on `VeryLazy`**, which can fire *after* `VimEnter` — a `VimEnter`-only autocmd silently never runs. Schedule the workspace initializer directly. Headless testing needs an explicit `doautocmd User VeryLazy`.
8. **Quitting during the first run aborts Mason installs.** Let the first `:Lazy`/`:Mason` sync finish before closing.
9. **npm may warn** about `allow-scripts` (`protobufjs` postinstall) and deprecated transitive deps when installing `@usebruno/cli`; `bru --version` works regardless.
10. Installing a CLI is not authenticating: `aws sso login`, `az login`, `gh auth login` are run only when the user explicitly confirms.

## Runtime-agnostic by design

Docker is the industry standard, but the spec does not lock you to Docker Desktop. The `Dockerfile` and `docker-compose.yml` you already have follow **open standards** (OCI image spec and the open-source Compose Specification), so the runtime is a swappable detail:

| Artifact | Standard | Docker Desktop | OrbStack | Rancher Desktop | Podman Desktop | Apple `container` |
|----------|----------|:---:|:---:|:---:|:---:|:---:|
| `Dockerfile` | OCI image spec | ✅ | ✅ | ✅ | ✅ | ✅ |
| `docker-compose.yml` | Compose Specification | ✅ | ✅ | ✅ (ships real docker-compose) | ✅ (podman-compose, ~95% parity) | ❌ (3rd-party bridges only) |
| OCI images (Docker Hub, GHCR, ECR...) | OCI | ✅ | ✅ | ✅ | ✅ | ✅ |
| Same `docker` CLI | compatible APIs | ✅ | ✅ | ✅ | ✅ (alias) | ❌ (`container` CLI) |
| `lazydocker` (Containers tab) | container API | ✅ | ✅ | ✅ | ✅ | ❌ |

Per platform:

- **macOS:** OrbStack is the pragmatic pick (~200MB idle vs ~4GB Docker Desktop, ~2s boot). Apple's native `container` (v1.0, macOS 26) is one micro-VM per container with strong isolation and low host overhead — worth tracking, but no native Compose yet, so not ready for multi-container stacks.
- **Windows:** Docker Desktop → WSL2 + plain Docker CLI (lightest, drops the Desktop license), Rancher Desktop (open source, optional K8s) or Podman Desktop (daemonless, rootless).

The `lazydocker` Containers tab works unchanged with any Docker-API-compatible backend.

## Secrets policy

No credentials in the repo, the spec, or the config. Use `aws sso login` / `az login` / `gh auth login` (only when the user explicitly confirms), per-tab env vars, git-ignored `.env` files, or a secrets CLI (e.g., 1Password `op`).

## Status

**Windows 11 x64 (validated):** 11 named tabs with correct `tcd`, tree-sitter 0.27.0 + lazygit 0.65.1 running, 23/23 parsers, zero spawn errors cycling all tabs, 70ms lazy boot (5/58 plugins), `:NewTabProject` with per-tab env, Snacks terminal keymaps removed.

**macOS M4 16 GB (specified, not yet validated):** full Homebrew path above; ported automatically by the same `lua/config/*` — the only expected differences are the shell (`zsh`), `az` being a native binary, and terminal-protocol caveats. Validation notes should be added here after a real run.

**Open items on every platform:** real-project LSP sessions (roslyn/vtsls/angularls), dadbod against a live database, cloud logins, Angular test-runner choice (detect from `package.json`), IaC (Bicep/Terraform — install on demand), `lazyredis` tap verification.
