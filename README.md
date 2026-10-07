# Neovim as a Full-Cycle AI-Driven Development Lifecycle (AIDLC) IDE

A battle-tested specification for turning Neovim (LazyVim) into a complete, terminal-first IDE for **AI-driven development** — isolated workspaces per domain, per-tab terminals, lazy LSPs, and a CLI-only toolchain.

Tested on **Windows 11 x64 / Neovim 0.12**, designed to be portable to macOS/Linux with minimal changes.

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

Measured result: **5/58 plugins loaded in 70ms** at boot; LSPs start only when a matching file opens.

## Plugin stack (Lazy.nvim / LazyVim)

- **UI:** neo-tree, native tabline reading `vim.t.tab_name` (plain text, no emojis), scope.nvim
- **Terminal:** toggleterm.nvim, one instance per tab, scoped to the tab's `tcd`
- **LSP (Mason):** roslyn.nvim (C#), vtsls + angularls, marksman, dockerls, yamlls + SchemaStore
- **Format/Lint:** conform.nvim (csharpier, prettier), ESLint, hadolint, actionlint
- **Debug/Test:** nvim-dap + nvim-dap-ui (netcoredbg, js-debug-adapter); neotest-dotnet + Jest/Vitest adapter
- **Git:** gitsigns, diffview.nvim, octo.nvim, lazygit
- **AI:** coder/claudecode.nvim (selection + diagnostics visible to the agent, diffs open in-editor)
- **Notes/API:** markdown-preview.nvim, render-markdown.nvim, Bruno `.bru` filetype

## Windows-specific gotchas (learned the hard way)

These cost real debugging time — don't rediscover them:

1. **Smart App Control blocks unsigned binaries** (`tree-sitter.exe` from Mason, `lazygit.exe` from winget) *even after* they run in other shells. SAC is **irreversibly disabled** by `VerifiedAndReputablePolicyState = 0` + reboot — verify binaries run *before* blaming your config.
2. **Neovim 0.12 rejects an empty `env` table in `termopen`** (`E475: Invalid argument: env`). Pass `env` only when it has keys, or toggleterm fails and you get a confusing cascade (`E21: modifiable is off`).
3. **Azure CLI is `az.cmd` on Windows** — `vim.system({"az"})` via libuv won't run it reliably. Use `cmd.exe /c` and cache the result; never call `az` on every statusline redraw.
4. **Default shell is `cmd.exe`**, not PowerShell — don't document PowerShell as the internal shell without configuring it.
5. **`vim.fs.isabs` and `nvim_tabpage_call` may not exist** in your build — validate every Neovim API against the installed version.
6. **New `PATH` entries need a terminal restart** — existing processes keep stale env vars.
7. **Windows CLI shims are `.cmd` files** — check `executable()` and shell wrappers before enabling lazy execution.

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

Validated on Windows 11: 11 named tabs with correct `tcd`, tree-sitter 0.27.0 + lazygit 0.65.1 running, 23/23 parsers, zero spawn errors cycling all tabs, 70ms lazy boot.

Not yet assumed: real-project LSP sessions, live cloud logins, Angular test-runner choice (detect from `package.json`), IaC (Bicep/Terraform — install on demand).
