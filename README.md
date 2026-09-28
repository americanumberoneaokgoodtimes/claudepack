# claudepack

**Seamlessly transfer entire Claude Code projects between machines.**

`/pack` and `/unpack` are Claude Code slash commands that zip your entire project — files, conversation memory, custom commands, settings, and hooks — and restore it on another machine so that when you restart Claude Code, it picks up exactly where you left off.

---

## What it transfers

| Item | Description |
|------|-------------|
| Project files | Everything in the current working directory (with configurable exclusions) |
| Claude session memory | Conversation context, facts Claude has remembered about your project |
| Custom commands | Your `.claude/commands/` slash commands (including `/pack` and `/unpack` themselves) |
| Settings & hooks | `settings.json`, hooks configuration |
| Global config | `~/.claude/CLAUDE.md` global instructions |
| Git history | Optional — off by default due to size |

After running `/unpack` and restarting Claude Code, the session is indistinguishable from the source machine.

---

## Installation

### Option A — One-liner (Unix/Mac)
```bash
mkdir -p ~/.claude/commands && \
  curl -L -o ~/.claude/commands/pack.md \
    https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/commands/pack.md && \
  curl -L -o ~/.claude/commands/unpack.md \
    https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/commands/unpack.md
```

### Option B — One-liner (Windows PowerShell)
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\commands" -Force | Out-Null
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/commands/pack.md" `
  -OutFile "$env:USERPROFILE\.claude\commands\pack.md"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/commands/unpack.md" `
  -OutFile "$env:USERPROFILE\.claude\commands\unpack.md"
```

### Option C — Manual
Copy `commands/pack.md` and `commands/unpack.md` to `~/.claude/commands/`.

On Windows: `C:\Users\<you>\.claude\commands\`
On Unix/Mac: `~/.claude/commands/`

---

## Usage

### Installing claudepack on another machine (no internet required)

If the other machine doesn't have `/pack` and `/unpack` yet, run this on the machine that **does** have them:

```
/pack install
```

Claude will:
1. Find the installed `pack.md` and `unpack.md` on this machine
2. Generate `install.sh` and `install.ps1` pointing to this machine's LAN IP
3. Launch a local HTTP server serving all four files
4. Print two ready-to-run one-liners for the other machine:

```
Unix/Mac (hostname):  curl -fsSL http://b4ke:8741/install.sh | bash
Unix/Mac (IP):        curl -fsSL http://192.168.1.42:8741/install.sh | bash
Windows (hostname):   iwr http://b4ke:8741/install.ps1 | iex
Windows (IP):         iwr http://192.168.1.42:8741/install.ps1 | iex
```

The other machine runs one line, gets `/pack` and `/unpack` installed, and is ready. Nothing touches the internet.

---

### Exporting a project (source machine)

```
/pack
```

Claude will:
1. Scan your project and report sizes
2. Walk you through an interactive wizard (what to include, exclusions, transfer method)
3. Warn you if the pack exceeds 4 GB
4. Build `claudepack_<projectname>_<timestamp>.zip`
5. Launch a local HTTP server and print the `/unpack` command to run on the other machine

### Importing a project (destination machine)

```
/unpack http://192.168.1.42:8743/claudepack_myproject_20260928_143200.zip
```

Or with a token URL:
```
/unpack http://192.168.1.42:8743/Xk9mP2qRtYvNwLdJ8cZa/claudepack_myproject_20260928_143200.zip
```

Or from a local file:
```
/unpack ./claudepack_myproject_20260928_143200.zip
```

Claude will:
1. Download the archive (with resume support if interrupted)
2. Validate integrity
3. Show a manifest summary of what's inside
4. Extract project files to a new folder
5. Restore session memory, commands, and settings to the exact locations Claude Code expects
6. Print `cd <folder>` + restart instructions

**After `cd` + restart, Claude Code loads your restored session automatically.**

---

## How the seamless restore works

Claude Code identifies projects by their CWD absolute path. Each path separator character (`:`, `\`, `/`) is replaced with `-` to form a directory name under `~/.claude/projects/`. For example:

- `C:\Users\o\myproject` → `~/.claude/projects/C--Users-o-myproject/`
- `/home/user/myproject` → `~/.claude/projects/-home-user-myproject/`

`/unpack` computes this hash for the destination folder before Claude Code ever opens it, and places memory files there. On restart, Claude finds them automatically.

---

## Transfer methods

| Method | Security | Requires |
|--------|----------|----------|
| HTTP Open | Anyone on LAN can download | python3, python, or npx |
| HTTP Token | URL-obscured (not enforced auth) | python3, python, or npx |
| No server | Manual file move | Nothing |

For sensitive projects on untrusted networks, use "No server" and transfer the zip via your own method (USB, cloud storage, scp, etc.).

---

## Requirements

- Claude Code CLI
- **Pack machine:** `python3` (or `python`) for HTTP server and manifest generation; `zip`/`rsync` on Unix, `robocopy`/PowerShell on Windows
- **Unpack machine:** `curl` for download (or PowerShell `Invoke-WebRequest`); `unzip` on Unix, PowerShell `Expand-Archive` on Windows; `python3` for settings merge

All of these are either pre-installed or widely available on modern systems.

---

## Exclusions (default)

The following are excluded from packs by default. You can add or remove exclusions in the wizard:

```
node_modules/, dist/, build/, .next/, out/, .nuxt/, .svelte-kit/,
__pycache__/, .cache/, .parcel-cache/, coverage/, .nyc_output/,
*.log, *.tmp, .DS_Store, Thumbs.db, desktop.ini
```

`.git/`, `node_modules/`, and `.env` files are off by default with size warnings shown.

---

## Security notes

- `.env` files and secrets are **excluded and off by default**. You must explicitly enable them and confirm a second time.
- The HTTP token mode obscures the URL but does not enforce authentication. Python's built-in `http.server` has no auth layer.
- The pack zip contains your full project source and Claude session memory. Treat it with the same care as your source code.
- Always Ctrl+C the server on the source machine once transfer is complete.

---

## License

MIT
