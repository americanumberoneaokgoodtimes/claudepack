# /pack — Seamless Claude Code Project Transfer (Export)

You are packaging this entire Claude Code project — files, memory, commands, settings, and history — so it can be restored on another machine with a single `/unpack` command and a Claude Code restart. The receiving machine should feel identical to this one.

---

## Subcommand Check — Read the Invocation First

If the user typed `/pack install`, jump immediately to the **`/pack install` — Bootstrap Installer** section at the bottom of this file. Do not run the normal pack wizard.

If the user typed `/pack` with no arguments (or with a URL/path argument), continue with Step 1 below.

---

## Step 1: Scan and Compute — Do This First, Silently

### 1a. Basic info
- CWD absolute path
- Project name: `basename` of CWD
- OS/platform (win32, linux, darwin)

### 1b. Compute the Claude project hash NOW

Claude Code identifies projects by their absolute CWD path. Every character that is `:`, `\`, or `/` is replaced with a single `-`.

**Windows** example — CWD: `C:\Users\o\myproject`
```
Character-by-character: C : \ U s e r s \ o \ m y p r o j e c t
Replace : and \ with -: C - - U s e r s - o - m y p r o j e c t
Result: C--Users-o-myproject
```
`C:\` → `C--` because the colon becomes `-` AND the backslash becomes `-`.

**Unix/Mac** example — CWD: `/home/user/myproject`
```
Replace / with -: - h o m e - u s e r - m y p r o j e c t
Result: -home-user-myproject
```

The Claude projects folder is: `~/.claude/projects/<computed-hash>/`
Verify it exists before scanning its size.

### 1c. Scan sizes
- Total uncompressed size of CWD:
  - Unix: `du -sh . 2>/dev/null`
  - Windows PowerShell: `"{0:N2} GB" -f ((Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB)`
- Individual sizes of: `.git/`, `node_modules/`, `dist/`, `build/`, `.next/`
- Count files matching sensitive patterns: `.env`, `*.key`, `*.pem`, `*.p12`, `*secret*`, `*credential*`, `*.pfx`
- Size of `~/.claude/projects/<computed-hash>/memory/`

### 1d. Report scan summary before wizard
```
📂 Project Scan: <project_name>
   Path     : <CWD>
   Total    : X.X GB (uncompressed, all files)
   Files    : ~N files

   Large directories detected:
     node_modules/  X.X GB  ← excluded by default
     .git/          X.X MB  ← excluded by default
     <others>       X.X MB

   Claude session memory : X.X MB
   Sensitive files found : N  ⚠️  (will warn before including)
```

---

## Step 2: Interactive Wizard

Present all options. Wait for explicit user confirmation before proceeding.

### 2a. Inclusion Options

```
What to include in the pack?

  [x] Project files (CWD)                        — always included, cannot disable
  [ ] .git history                                — X.X MB — OFF by default
  [x] Claude session memory                       — conversation context & memory files
  [x] Claude custom commands (.claude/commands/)  — your /slash commands including /pack and /unpack
  [x] Claude settings & hooks (.claude/settings.json)
  [x] Claude global config (~/.claude/CLAUDE.md)  — global instructions (if exists)
  [ ] node_modules / build artifacts              — X.X GB — OFF, recommend excluding
  [ ] .env / secret files                         — N found — OFF ⚠️  SENSITIVE — confirm before enabling
```

Show actual detected sizes. Ask user to confirm defaults or change any option.
If user enables .env/secrets, show an extra confirmation: "These files may contain passwords or API keys. Include anyway? [y/N]"

### 2b. Exclusion Patterns

Pre-apply these exclusions (always active — inform user):
```
node_modules/, dist/, build/, .next/, out/, .nuxt/, .svelte-kit/,
__pycache__/, .cache/, .parcel-cache/, coverage/, .nyc_output/,
*.log, *.tmp, .DS_Store, Thumbs.db, desktop.ini
```

List any directories >50MB not already on this list. Ask if user wants to add custom exclusion patterns (comma-separated globs accepted).

### 2c. Transfer Method

```
How should the file be served after packing?

  [1] HTTP — Open LAN   — no auth, anyone on your local network can download
  [2] HTTP — Token URL  — random 20-char token in the path, obscures the URL
  [3] No server         — just save the zip, I will move it myself
```

Note for option 2: python's built-in HTTP server cannot enforce auth — the token obscures the URL but does not block determined access. For sensitive projects on untrusted networks, use option 3.

Wait for user choice.

---

## Step 3: Size Estimate and 4 GB Warning

Calculate estimated included size after applying exclusions.

```
  Estimated uncompressed : X.XX GB
  Estimated compressed   : ~X.XX GB
```

**If estimated size exceeds 4 GB**, STOP and show:

```
⚠️  LARGE PACK WARNING — Estimated: X.X GB compressed

    This will take significant time to transfer even on a fast LAN.
    Recommended actions:
      • Exclude .git history (saves X.X MB)
      • Exclude large asset directories

    [1] Continue anyway
    [2] Go back and adjust exclusions
```

Do not proceed until user chooses.

---

## Step 4: Build the Archive

### Filename:
```
claudepack_<projectname>_<YYYYMMDD_HHMMSS>.zip
```

**Save location:** parent directory of CWD. If parent is not writable (e.g. CWD is a drive root), fall back to system temp (`$env:TEMP` on Windows, `/tmp` on Unix) and tell the user the path.

### Required internal structure:
```
claudepack_<name>_<ts>/
  project/          ← CWD contents with all exclusions applied
  claude/
    memory/         ← ~/.claude/projects/<hash>/memory/ (all files)
    commands/       ← ~/.claude/commands/*.md
    settings.json   ← ~/.claude/settings.json (if exists)
    CLAUDE.md       ← ~/.claude/CLAUDE.md (if exists and included)
  manifest.json     ← metadata (see schema below)
```

### Build using a staging directory (required on all platforms):

Create a temp staging dir, populate it with the exact structure above, then zip the whole thing. This guarantees the internal zip layout is correct regardless of platform.

**Unix/Mac:**
```bash
TS=$(date +%Y%m%d_%H%M%S)
NAME=$(basename "$PWD")
ZIPNAME="claudepack_${NAME}_${TS}.zip"
STAGE=$(mktemp -d)
ZIPROOT="${STAGE}/claudepack_${NAME}_${TS}"

# Create structure
mkdir -p "${ZIPROOT}/project" "${ZIPROOT}/claude/memory" "${ZIPROOT}/claude/commands"

# Copy project files with exclusions (build -x flags dynamically from user choices)
rsync -a --exclude='node_modules/' --exclude='.git/' --exclude='dist/' \
  --exclude='build/' --exclude='.next/' --exclude='__pycache__/' \
  --exclude='*.log' --exclude='*.tmp' --exclude='.DS_Store' \
  ./ "${ZIPROOT}/project/"
# If rsync not available, use: cp -r . "${ZIPROOT}/project/" then delete excluded dirs

# Copy claude data
HASH="<computed from Step 1b>"
cp -r ~/.claude/projects/${HASH}/memory/. "${ZIPROOT}/claude/memory/" 2>/dev/null || true
cp ~/.claude/commands/*.md "${ZIPROOT}/claude/commands/" 2>/dev/null || true
cp ~/.claude/settings.json "${ZIPROOT}/claude/" 2>/dev/null || true
cp ~/.claude/CLAUDE.md "${ZIPROOT}/claude/" 2>/dev/null || true

# Write manifest.json
python3 -c "
import json, os, datetime, socket, platform
manifest = {
    'claudepack_version': '1.0',
    'packed_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'source_host': socket.gethostname(),
    'source_os': platform.system().lower(),
    'project_name': os.path.basename(os.getcwd()),
    'original_cwd': os.getcwd(),
    'claude_project_hash': '<HASH>',
    'zip_root_dir': 'claudepack_${NAME}_${TS}',
    'includes': ['files','memory','commands','settings'],
    'excludes': ['node_modules','dist','build','.next','*.log','*.tmp'],
    'git_included': False,
    'git_remote_origin': None,
    'file_count': 0,
    'uncompressed_bytes': 0,
    'compressed_bytes': 0
}
print(json.dumps(manifest, indent=2))
" > "${ZIPROOT}/manifest.json"

# Zip and clean up
cd "${STAGE}"
zip -r "../${ZIPNAME}" "claudepack_${NAME}_${TS}/"
ZIPPATH="$(dirname $PWD)/${ZIPNAME}"
rm -rf "${STAGE}"
```

**Windows (PowerShell):**
```powershell
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$name = Split-Path -Leaf (Get-Location)
$zipName = "claudepack_${name}_${ts}.zip"
$stage = Join-Path $env:TEMP "claudepack_stage_${ts}"
$zipRoot = Join-Path $stage "claudepack_${name}_${ts}"

# Create structure
New-Item -ItemType Directory -Path "$zipRoot\project","$zipRoot\claude\memory","$zipRoot\claude\commands" -Force | Out-Null

# Copy project files
$hash = "<computed from Step 1b>"
robocopy (Get-Location) "$zipRoot\project" /E /XD node_modules dist build .git .next __pycache__ /XF *.log *.tmp /NFL /NDL /NJH /NJS | Out-Null

# Copy claude data
$claudeBase = "$env:USERPROFILE\.claude"
Copy-Item "$claudeBase\projects\$hash\memory\*" "$zipRoot\claude\memory\" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$claudeBase\commands\*.md" "$zipRoot\claude\commands\" -Force -ErrorAction SilentlyContinue
Copy-Item "$claudeBase\settings.json" "$zipRoot\claude\" -ErrorAction SilentlyContinue
Copy-Item "$claudeBase\CLAUDE.md" "$zipRoot\claude\" -ErrorAction SilentlyContinue

# Write manifest.json
$manifest = @{
    claudepack_version = "1.0"
    packed_at = (Get-Date).ToUniversalTime().ToString("o")
    source_host = $env:COMPUTERNAME
    source_os = "win32"
    project_name = $name
    original_cwd = (Get-Location).Path
    claude_project_hash = $hash
    zip_root_dir = "claudepack_${name}_${ts}"
    includes = @("files","memory","commands","settings")
    excludes = @("node_modules","dist","build",".git","*.log","*.tmp")
    git_included = $false
    git_remote_origin = $null
    file_count = 0
    uncompressed_bytes = 0
    compressed_bytes = 0
} | ConvertTo-Json
$manifest | Out-File "$zipRoot\manifest.json" -Encoding utf8

# Zip and clean up
$parentDir = Split-Path -Parent (Get-Location)
$zipPath = Join-Path $parentDir $zipName
Compress-Archive -Path "$zipRoot" -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force
```

### After zipping:
- Fill in `file_count`, `uncompressed_bytes`, `compressed_bytes` with real values
- Update manifest inside the zip if needed, or write correct values before zipping
- Show the user the actual compressed size in GB

---

## Step 5: Launch Transfer Server

### Find a free port (8700–8799):

**Unix:**
```bash
for PORT in $(shuf -i 8700-8799 -n 100); do
  python3 -c "import socket; s=socket.socket(); s.bind(('',${PORT})); s.close()" 2>/dev/null && echo $PORT && break
done
```

**Windows (PowerShell):**
```powershell
$port = 8700..8799 | Get-Random -Count 100 | ForEach-Object {
    try { $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any,$_); $l.Start(); $l.Stop(); $_; break } catch {}
} | Select-Object -First 1
```

### Detect LAN IP:
- **Linux/Mac:** `hostname -I 2>/dev/null | awk '{print $1}'`
- **Windows PowerShell:** `(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Sort-Object PrefixLength | Select-Object -First 1).IPAddress`

### Option 1 — HTTP Open:
```bash
cd "$(dirname $ZIPPATH)"
python3 -m http.server $PORT
# fallback: python -m SimpleHTTPServer $PORT
# fallback: npx --yes serve -p $PORT .
# if none available: show file path, skip server
```

### Option 2 — HTTP Token:
```bash
TOKEN=$(python3 -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(20)))")
SERVE_DIR=$(mktemp -d)
mkdir -p "${SERVE_DIR}/${TOKEN}"
cp "$ZIPPATH" "${SERVE_DIR}/${TOKEN}/"
cd "$SERVE_DIR"
python3 -m http.server $PORT
# URL: http://<LAN-IP>:<PORT>/<TOKEN>/claudepack_<name>_<ts>.zip
```
Windows equivalent: use `$env:TEMP\claudepack_serve_$ts\$token\` and serve with `python3` or `npx serve`.

### Option 3 — No Server:
Skip to handoff block.

---

## Step 6: Print Handoff Block

```
╔══════════════════════════════════════════════════════════════════════╗
║  ✅ CLAUDEPACK READY                                                 ║
║                                                                      ║
║  File  : claudepack_<name>_<ts>.zip                                  ║
║  Size  : X.XX GB compressed                                          ║
║  Saved : <full absolute path to zip>                                 ║
║  URL   : http://<ip>:<port>/[<token>/]claudepack_<name>_<ts>.zip     ║
║                                                                      ║
║  ── On the other machine, run: ────────────────────────────────────  ║
║                                                                      ║
║  /unpack http://<ip>:<port>/[<token>/]claudepack_<name>_<ts>.zip     ║
║                                                                      ║
║  ── Or download with curl then run /unpack on the file: ───────────  ║
║  curl -L -C - -O http://<ip>:<port>/[<token>/]claudepack_<name>.zip  ║
║                                                                      ║
║  Keep this terminal open. Press Ctrl+C when transfer is complete.    ║
╚══════════════════════════════════════════════════════════════════════╝
```

Keep the server running. Do not exit until user confirms transfer complete or presses Ctrl+C.

---

## `/pack install` — Bootstrap Installer

**Trigger:** user typed `/pack install`

The other machine does not yet have `/pack` or `/unpack`. This subcommand serves the command files directly from this machine so the other machine can install them with a single copy-paste line. Nothing is downloaded from the internet — everything comes from the files already installed on this machine.

---

### Step I-1: Locate the installed command files

Find `pack.md` and `unpack.md` on this machine:

**Unix/Mac:**
```bash
PACK_SRC=~/.claude/commands/pack.md
UNPACK_SRC=~/.claude/commands/unpack.md
```

**Windows PowerShell:**
```powershell
$packSrc   = "$env:USERPROFILE\.claude\commands\pack.md"
$unpackSrc = "$env:USERPROFILE\.claude\commands\unpack.md"
```

If either file is missing, stop and tell the user:
```
❌ Cannot find pack.md or unpack.md in ~/.claude/commands/
   This machine may not have claudepack installed correctly.
   Re-install from: https://github.com/YOUR_USERNAME/claudepack
```

---

### Step I-2: Generate bootstrap scripts on-the-fly

Create a temporary serve directory and populate it with the command files plus generated installer scripts that point to this machine's IP and port.

First, pick a free port (8700–8799) using the same method as Step 5 of the main pack flow.
Then detect the LAN IP using the same method as Step 5.

**Build the serve directory:**

```
/tmp/claudepack_install_<ts>/
  pack.md           ← copy of ~/.claude/commands/pack.md
  unpack.md         ← copy of ~/.claude/commands/unpack.md
  install.sh        ← generated Unix/Mac installer (points to this IP:port)
  install.ps1       ← generated Windows installer (points to this IP:port)
```

**Generate `install.sh` with the actual IP and port substituted in:**

```bash
cat > "${SERVE_DIR}/install.sh" << SCRIPT
#!/usr/bin/env bash
set -e
COMMANDS_DIR="\${HOME}/.claude/commands"
BASE_URL="http://<LAN_IP>:<PORT>"
echo "Installing claudepack from ${BASE_URL}..."
mkdir -p "\$COMMANDS_DIR"
curl -fsSL -o "\${COMMANDS_DIR}/pack.md"   "\${BASE_URL}/pack.md"
curl -fsSL -o "\${COMMANDS_DIR}/unpack.md" "\${BASE_URL}/unpack.md"
echo ""
echo "✅ Installed. Restart Claude Code, then use /pack and /unpack."
SCRIPT
chmod +x "${SERVE_DIR}/install.sh"
```

**Generate `install.ps1` with the actual IP and port substituted in:**

```powershell
$installScript = @"
`$ErrorActionPreference = "Stop"
`$commandsDir = "`$env:USERPROFILE\.claude\commands"
`$baseUrl = "http://<LAN_IP>:<PORT>"
Write-Host "Installing claudepack from `$baseUrl..."
New-Item -ItemType Directory -Path `$commandsDir -Force | Out-Null
Invoke-WebRequest -Uri "`$baseUrl/pack.md"   -OutFile "`$commandsDir\pack.md"
Invoke-WebRequest -Uri "`$baseUrl/unpack.md" -OutFile "`$commandsDir\unpack.md"
Write-Host ""
Write-Host "Installed. Restart Claude Code, then use /pack and /unpack."
"@
$installScript | Out-File "$serveDir\install.ps1" -Encoding utf8
```

Copy the command files into the serve directory:
```bash
cp "$PACK_SRC"   "${SERVE_DIR}/pack.md"
cp "$UNPACK_SRC" "${SERVE_DIR}/unpack.md"
```

---

### Step I-3: Launch the HTTP server

Serve the directory over HTTP (no token needed — these are not sensitive files):

**Unix/Mac:**
```bash
cd "$SERVE_DIR"
python3 -m http.server $PORT
# fallback: python -m SimpleHTTPServer $PORT
# fallback: npx --yes serve -p $PORT .
```

**Windows PowerShell:**
```powershell
Set-Location $serveDir
python3 -m http.server $port
```

---

### Step I-4: Detect hostname

Get the short hostname of this machine (not the FQDN):

**Unix/Mac:**
```bash
HOSTNAME=$(hostname -s 2>/dev/null || hostname)
```

**Windows PowerShell:**
```powershell
$hostName = $env:COMPUTERNAME
```

Both `<LAN_IP>` and `<HOSTNAME>` resolve to the same machine on most LANs. Include both in the install block — hostname is more readable, IP is the reliable fallback if hostname DNS doesn't propagate on the LAN.

---

### Step I-5: Print the Install Block

Print this block immediately after the server starts, before anything else:

```
╔══════════════════════════════════════════════════════════════════════╗
║  📦 CLAUDEPACK INSTALL SERVER READY                                  ║
║                                                                      ║
║  On the other machine, run ONE of these:                             ║
║                                                                      ║
║  Unix/Mac (by hostname — try this first):                            ║
║  curl -fsSL http://<hostname>:<port>/install.sh | bash               ║
║                                                                      ║
║  Unix/Mac (by IP — if hostname doesn't resolve):                     ║
║  curl -fsSL http://<ip>:<port>/install.sh | bash                     ║
║                                                                      ║
║  Windows PowerShell (by hostname):                                   ║
║  iwr http://<hostname>:<port>/install.ps1 | iex                      ║
║                                                                      ║
║  Windows PowerShell (by IP):                                         ║
║  iwr http://<ip>:<port>/install.ps1 | iex                            ║
║                                                                      ║
║  ── Or install manually: ─────────────────────────────────────────  ║
║  http://<hostname>:<port>/pack.md                                    ║
║  http://<hostname>:<port>/unpack.md                                  ║
║  Copy both to ~/.claude/commands/ and restart Claude Code.           ║
║                                                                      ║
║  After install, the other machine can run /pack and /unpack.         ║
║  Press Ctrl+C here when done.                                        ║
╚══════════════════════════════════════════════════════════════════════╝
```

Keep the server running until the user presses Ctrl+C.

Cleanup: after Ctrl+C, delete the temporary serve directory.
```bash
rm -rf "$SERVE_DIR"    # Unix
Remove-Item $serveDir -Recurse -Force   # Windows
```
