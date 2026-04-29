# ============================================================
# Elnora Starter Kit - One-liner Installer (Windows)
# ============================================================
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/Elnora-AI/elnora-starter-kit/main/install.ps1 | iex
#
# Prompts for a workspace name (used for BOTH the local folder name AND
# the GitHub repo name created in Phase 2), downloads the starter kit zip
# (no git required), extracts to %USERPROFILE%\Documents\<workspace-name>,
# and runs setup-windows.ps1.
# ============================================================

$ErrorActionPreference = "Stop"

# Force TLS 1.2 for the Invoke-WebRequest below. Windows PowerShell 5.1 (the
# default on Win10/11) defaults to SSL3/TLS 1.0 on older unpatched builds;
# GitHub's CDN (codeload.github.com) rejects that handshake and the zip
# download fails with an opaque "underlying connection was closed" error
# before we reach setup-windows.ps1. Mirrors the same fix that setup-windows.ps1
# applies to its installer sub-processes.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoOwner = "Elnora-AI"
$RepoName  = "elnora-starter-kit"
$Branch    = "main"

# ---- Workspace name -------------------------------------------------------
# This name is used for BOTH the local folder under Documents\ AND the
# GitHub repo we create later in Phase 2. Locking them in lockstep up
# front avoids a class of bugs where the local path and GitHub remote
# drift out of sync.
#
# Resolution order:
#   1. $env:ELNORA_WORKSPACE_NAME (CI / scripted runs).
#   2. Interactive Read-Host prompt (irm | iex runs in the caller's
#      session, so Read-Host reaches the real console).
#   3. Fallback to "elnora-starter-kit" for non-interactive contexts
#      with no env override.
#
# Validation matches the handoff doc's GitHub repo-name rule
# ([A-Za-z0-9._-]+) so whatever the user picks here is also a legal
# `gh repo create` argument.
$nameRegex = '^[A-Za-z0-9._-]+$'
$defaultName = "$env:USERNAME-agents"
if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { $defaultName = "me-agents" }

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Elnora Starter Kit - Bootstrap" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if (-not [string]::IsNullOrWhiteSpace($env:ELNORA_WORKSPACE_NAME)) {
    $WorkspaceName = $env:ELNORA_WORKSPACE_NAME
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
    Write-Host "Pick a name for your workspace. This becomes BOTH:"
    Write-Host "  - the local folder under $env:USERPROFILE\Documents\"
    Write-Host "  - the GitHub repo we'll create for you in Phase 2"
    Write-Host ""
    Write-Host "Letters, numbers, dots, dashes, and underscores only."
    Write-Host ""
    while ($true) {
        $reply = Read-Host -Prompt "Workspace name [$defaultName]"
        if ([string]::IsNullOrWhiteSpace($reply)) { $reply = $defaultName }
        if ($reply -match $nameRegex) {
            $WorkspaceName = $reply
            break
        }
        Write-Host "  [!] '$reply' isn't a legal name. Try again." -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    $WorkspaceName = "elnora-starter-kit"
}

if ($WorkspaceName -notmatch $nameRegex) {
    Write-Host "[!] ELNORA_WORKSPACE_NAME='$WorkspaceName' is not a legal repo name." -ForegroundColor Red
    Write-Host "    Allowed: letters, digits, dot, dash, underscore." -ForegroundColor Red
    throw "Invalid workspace name: $WorkspaceName"
}

$TargetDir = Join-Path $env:USERPROFILE "Documents\$WorkspaceName"

Write-Host "This will:"
Write-Host "  1. Download the starter kit to $TargetDir"
Write-Host "  2. Run setup-windows.ps1 (installs Claude Code + dev tools)"
Write-Host ""

# Always wipe + re-extract on every run. If the customer is running this
# script again it's because something didn't work the first time -- they
# want a fresh starting point, not a half-stale copy of last week's repo.
# System tools (Claude, Node, Python, Obsidian) are NOT touched here:
# setup-windows.ps1 detects existing installs and updates in place, so
# re-running won't blow away a working toolchain.
if (Test-Path $TargetDir) {
    Write-Host "Existing starter kit detected at $TargetDir" -ForegroundColor Gray
    Write-Host "Wiping for a fresh install (system tools like Claude, Node, Python are kept)..." -ForegroundColor Gray
    Remove-Item -Path $TargetDir -Recurse -Force
}

Write-Host "Downloading starter kit zip..." -ForegroundColor Green
$zipUrl  = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
$zipPath = Join-Path $env:TEMP "$RepoName-bootstrap.zip"
$tmpExtractDir = Join-Path $env:TEMP "$RepoName-bootstrap"

try {
    # Retry up to 3 times on flaky networks (hotel / conference wifi).
    # -TimeoutSec caps the whole request; retries cover transient DNS/TLS
    # hiccups that return immediately instead of hanging.
    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            break
        } catch {
            if ($attempt -eq $maxAttempts) { throw }
            Write-Host "  Download attempt $attempt failed: $($_.Exception.Message). Retrying in 2s..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    if (Test-Path $tmpExtractDir) { Remove-Item $tmpExtractDir -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $tmpExtractDir -Force

    $extracted = Join-Path $tmpExtractDir "$RepoName-$Branch"
    if (-not (Test-Path $extracted)) {
        throw "Expected folder not found after extract: $extracted"
    }

    New-Item -ItemType Directory -Path (Split-Path $TargetDir -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
    Move-Item -Path $extracted -Destination $TargetDir -Force
    Write-Host "Extracted to $TargetDir" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to download starter kit from $zipUrl" -ForegroundColor Red
    Write-Host "    Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Check your internet connection and retry:" -ForegroundColor Red
    Write-Host "      irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/install.ps1 | iex" -ForegroundColor Red
    # `throw` instead of `exit 1`: this script is invoked via `irm ... | iex`,
    # which runs in the caller's scope. `exit` would terminate the caller's
    # shell/parent script silently; `throw` surfaces as a catchable error and
    # still halts this installer if uncaught. Same reasoning as Bug 2 in the
    # elnora-cli handoff doc.
    throw "Starter kit bootstrap: failed to download from $zipUrl ($($_.Exception.Message))"
} finally {
    if (Test-Path $zipPath)       { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpExtractDir) { Remove-Item $tmpExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Set-Location $TargetDir

# Strip dev/CI scaffolding the customer can't use anyway. tests/handoff/ exists
# for our CI assertions; .github/ holds workflows + dependabot config that only
# fire on the official Elnora-AI/elnora-starter-kit repo. Both ride along in the
# zip and would just clutter the customer's directory. -ErrorAction
# SilentlyContinue keeps this idempotent on re-runs after the dirs are gone.
Write-Host "Stripping dev/CI scaffolding (tests/, .github/)..." -ForegroundColor Cyan
Remove-Item -Path (Join-Path $TargetDir "tests")   -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $TargetDir ".github") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  Done." -ForegroundColor Gray

# Write a marker file recording the SHA256 of INSTALL_FOR_AGENTS.md as it was
# extracted from GitHub. setup-windows.ps1 verifies this hash before handing
# off to claude with bypassPermissions -- if a third party tampers with the
# doc between extract and setup, the verify step trips and the handoff
# aborts. This is the trust anchor for the headless Phase 2 flow.
#
# Every install.ps1 run is a fresh extract from the official zip (we always
# wipe + re-download above), so re-blessing here is correct: the doc is
# always exactly what GitHub just served, and the marker stays in lockstep
# with whatever INSTALL_FOR_AGENTS.md content the customer is about to run.
$markerPath = Join-Path $TargetDir ".elnora-starter-kit-marker"
$installForAgentsPath = Join-Path $TargetDir "INSTALL_FOR_AGENTS.md"
if (Test-Path -LiteralPath $installForAgentsPath) {
    $hash = (Get-FileHash -Path $installForAgentsPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $markerContent = "version: 1`ncreated: $now`ninstall_for_agents_sha256: $hash`n"
    [System.IO.File]::WriteAllText($markerPath, $markerContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Wrote integrity marker (.elnora-starter-kit-marker)." -ForegroundColor Gray
}

# Bypass execution policy for this process only so setup-windows.ps1 runs
# without requiring the user to set it manually (as the older flow did).
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Host ""
& .\setup-windows.ps1
