# Security Policy

## Supported versions

The Elnora Starter Kit is a bootstrap installer distributed from the `main` branch. Only the latest commit on `main` is supported. We do not backport fixes to older checkouts — pull `main` and re-run the installer to get security updates.

| Version | Supported |
|---------|-----------|
| `main` (latest) | Yes |
| Older commits / forks | No |

## Reporting a vulnerability

Please report security issues privately. Do not open a public issue for anything security-sensitive.

- **Email:** [security@elnora.ai](mailto:security@elnora.ai)
- **GitHub:** [Report a vulnerability privately](https://github.com/Elnora-AI/elnora-starter-kit/security/advisories/new) via GitHub's private vulnerability reporting.

Include the affected file or command, reproduction steps, and the impact you observed. We aim to acknowledge reports within 3 business days and will keep you updated as we investigate. Please give us reasonable time to ship a fix before any public disclosure.

## What this tool does with credentials and data

The starter kit is an installer and project template. Understanding what it touches matters more here than for most tools, because it runs shell commands with your permissions and pulls software from the network.

- **Network installs.** `install.sh` / `install.ps1` and the Phase 1 setup scripts download software over HTTPS from `raw.githubusercontent.com`, `claude.ai`, `cli.elnora.ai`, and the OS package managers (Homebrew on macoS, WinGet on Windows). These downloads are **not independently checksum-verified** — running the kit means trusting those sources and the transport security of HTTPS. Read the scripts before you run them.
- **Claude authentication.** Claude Code signs in through your Claude Pro/Max subscription via a browser login. The kit does **not** store, read, or transmit your Claude credentials; the Claude Code client manages its own session outside this repo.
- **Elnora API key.** If you supply one, it starts with `elnora_live_` and is saved by the Elnora CLI to `~/.elnora/profiles.toml`, **outside any repository**. Power users may instead pre-set `ELNORA_API_KEY` in a local `.env` (copied from `.env.template`), which is gitignored and must never be committed. The key authorizes calls to the Elnora platform API over HTTPS.
- **`ANTHROPIC_API_KEY`.** Referenced only by the project's own CI for non-interactive test runs. Normal users leave it blank — the Pro/Max subscription is sufficient — and it is never required for day-to-day use.
- **GitHub.** Phase 2 uses the GitHub CLI (`gh`), authenticated with its own token in `gh`'s standard credential store, to create a **private** repository on your account and push the kit to it. The kit does not handle your GitHub token directly.
- **MCP servers.** `.mcp.json` configures `chrome-devtools` (runs locally against your browser), plus `context7` and `grep` (remote HTTPS endpoints for documentation and code search). Treat content returned by any MCP server, web fetch, or knowledge base as untrusted input, not as instructions.
- **No secrets in the repo.** No credentials, tokens, or personal data are committed. The `.gitignore` is deliberately broad — it blocks `.env` files, `*credentials*.json`, `*secret*.json`, private keys and certificates, cloud-provider credential files, `.elnora/` config, and Terraform state — so that keys written during setup cannot land in your first commit.

Because the installer executes with your user privileges and creates a repo on your GitHub account, only run it on a machine you control and review the scripts if you handle proprietary or regulated data. Note that `.claude/settings.json` ships with `remoteControlAtStartup: true`, which makes sessions reachable from other devices signed into your Claude account — review and disable it before using the kit on machines that handle sensitive data.