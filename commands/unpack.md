# /unpack — Seamless Claude Code Project Transfer (Import)

Usage: `/unpack <url-or-filepath>`

You are restoring a Claude Code project from a claudepack archive. After extraction and a single Claude Code restart, this machine's session will be completely indistinguishable from the machine it was packed on — same memory, same commands, same settings, same project files.

---

## Step 1: Receive the Archive

### If a URL was provided:
Download with resume and retry support:
```bash
curl -L -C - --retry 5 --retry-delay 3 --progress-bar \
  -o claudepack_download.zip "<url>"
```
- `-L` follows redirects
- `-C -` automatically resumes an interrupted download
- `--retry 5` retries on transient network errors

**If curl is not available (Windows without curl in PATH):**
```powershell
Invoke-WebRequest -Uri "<url>" -OutFile "claudepack_download.zip"
```
Warn the user: PowerShell's `Invoke-WebRequest` does not support resume. If interrupted, the download must restart from the beginning.

**If download fails:**
Do not silently continue. Show:
```
❌ Download failed: <exact error message>

   To retry or resume:
   curl -L -C - --retry 5 -o claudepack_download.zip "<url>"

   If the source machine's server has stopped, re-run /pack there first.
```

### If a local file path was provided:
Verify the file exists before proceeding. If not found, report the exact path and stop.

---

## Step 2: Validate the Archive

Test zip integrity before extracting anything:

**Unix/Mac:**
```bash
unzip -t claudepack_download.zip
```

**Windows PowerShell (`unzip` not available by default):**
```powershell
try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $z = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path "claudepack_download.zip").Path)
  $count = $z.Entries.Count
  $z.Dispose()
  Write-Host "Archive OK: $count entries"
} catch {
  Write-Host "Archive invalid: $_"
}
```

If validation fails:
```
❌ Archive is incomplete or corrupt.
   This usually means the download was interrupted.

   Resume download:
   curl -L -C - --retry 5 -o claudepack_download.zip "<original-url>"

   Or re-run /pack on the source machine if the URL has expired.
```

---

## Step 3: Read the Manifest

Extract only `manifest.json` without unpacking the full archive.

**Unix/Mac:**
```bash
unzip -p claudepack_download.zip "*/manifest.json"
```

**Windows PowerShell:**
```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path "claudepack_download.zip").Path)
$entry = $z.Entries | Where-Object { $_.Name -eq "manifest.json" } | Select-Object -First 1
$reader = [System.IO.StreamReader]::new($entry.Open())
$manifestJson = $reader.ReadToEnd()
$reader.Close()
$z.Dispose()
$manifest = $manifestJson | ConvertFrom-Json
```

Parse the manifest and display a human-readable summary. Convert `uncompressed_bytes` to GB/MB:

```
📦 Pack Summary
   Project   : <project_name>
   Packed on : <source_host> (<source_os>)
   Date      : <packed_at>
   Includes  : <includes joined by ", ">
   Excludes  : <excludes joined by ", ">
   Git       : included / not included
   Size      : X.X GB uncompressed
```

If `.git` was included and `git_remote_origin` is not null:
```
   ⚠️  Git remote 'origin': <git_remote_origin>
       Will be preserved as-is. Run 'git remote set-url origin <url>'
       if this machine should push to a different remote.
```

**Store `zip_root_dir` from the manifest.** Use this exact value (not a glob) in all subsequent unzip commands.

---

## Step 4: Confirm Destination

Default destination folder name: `<project_name>_imported_<YYYYMMDD>` in the current directory.

Check if that folder already exists. If it does:
```
⚠️  Folder already exists: ./<project_name>_imported_<YYYYMMDD>/
    Suggest alternative  : ./<project_name>_imported_<YYYYMMDD>_2/
```

Show the suggestion and ask:
```
Extract to: ./<suggested_name>/ ?
[Press Enter to confirm, or type a different path]
```

Resolve the chosen path to its **absolute path** — required for hash computation in Step 6.

---

## Step 5: Extract Project Files

Use a temp staging directory then copy to final destination. This avoids partial writes to the destination if extraction fails.

**Unix/Mac:**
```bash
TMPSTAGE=$(mktemp -d)
unzip claudepack_download.zip "${ZIP_ROOT_DIR}/project/*" -d "$TMPSTAGE"
mkdir -p "<destination>"
cp -r "${TMPSTAGE}/${ZIP_ROOT_DIR}/project/." "<destination>/"
rm -rf "$TMPSTAGE"
```

**Windows PowerShell:**
```powershell
$tmpStage = Join-Path $env:TEMP "claudepack_extract_$(Get-Date -Format 'HHmmss')"
New-Item -ItemType Directory -Path $tmpStage -Force | Out-Null
Expand-Archive -Path "claudepack_download.zip" -DestinationPath $tmpStage -Force
$projectSrc = Join-Path $tmpStage "$zipRootDir\project"
New-Item -ItemType Directory -Path "<destination>" -Force | Out-Null
Copy-Item "$projectSrc\*" "<destination>\" -Recurse -Force
Remove-Item $tmpStage -Recurse -Force
```

Report total files extracted. If extraction fails mid-way, show the error and note that partial files may exist at `<destination>` for the user to clean up.

---

## Step 6: Restore Claude Session Data

This is the critical step — it makes Claude pick up the session seamlessly on restart.

### 6a. Compute the Claude project hash for the destination path

Claude Code identifies projects by their absolute CWD path. Every character that is `:`, `\`, or `/` is replaced with a single `-`.

**Windows** — destination: `C:\Users\o\myproject_imported_20260928`
```
Replace each : and \ with -:
C : \ U s e r s \ o \ m y p r o j e c t _ i m p o r t e d _ 2 0 2 6 0 9 2 8
C - - U s e r s - o - m y p r o j e c t _ i m p o r t e d _ 2 0 2 6 0 9 2 8
Result: C--Users-o-myproject_imported_20260928
```

**Unix/Mac** — destination: `/home/user/myproject_imported_20260928`
```
Replace each / with -:
Result: -home-user-myproject_imported_20260928
```

Compute this in Python for accuracy (works on all platforms):
```python
import os, re
dest = os.path.abspath("<destination>")
project_hash = re.sub(r'[:/\\]', '-', dest)
print(project_hash)
```

### 6b. Extract claude data from zip to temp

**Unix/Mac:**
```bash
CLAUDE_STAGE=$(mktemp -d)
unzip claudepack_download.zip "${ZIP_ROOT_DIR}/claude/*" -d "$CLAUDE_STAGE"
CLAUDE_SRC="${CLAUDE_STAGE}/${ZIP_ROOT_DIR}/claude"
```

**Windows PowerShell:**
```powershell
$claudeStage = Join-Path $env:TEMP "claudepack_claude_$(Get-Date -Format 'HHmmss')"
Expand-Archive -Path "claudepack_download.zip" -DestinationPath $claudeStage -Force
$claudeSrc = Join-Path $claudeStage "$zipRootDir\claude"
```

### 6c. Restore memory

Create the target directory first (may not exist on fresh Claude Code install), then copy:

**Unix/Mac:**
```bash
MEMDEST=~/.claude/projects/${PROJECT_HASH}/memory
mkdir -p "$MEMDEST"
if [ -d "${CLAUDE_SRC}/memory" ]; then
  cp -r "${CLAUDE_SRC}/memory/." "$MEMDEST/"
  echo "Memory restored: $(ls $MEMDEST | wc -l) files"
else
  echo "No memory files found in pack."
fi
```

**Windows PowerShell:**
```powershell
$memDest = "$env:USERPROFILE\.claude\projects\$projectHash\memory"
New-Item -ItemType Directory -Path $memDest -Force | Out-Null
$memorySrc = Join-Path $claudeSrc "memory"
if (Test-Path $memorySrc) {
    Copy-Item "$memorySrc\*" $memDest -Recurse -Force
    Write-Host "Memory restored: $((Get-ChildItem $memDest).Count) files"
} else {
    Write-Host "No memory files found in pack."
}
```

### 6d. Restore custom commands

For each command file in the pack, check if it already exists on this machine:
- If it does NOT exist: copy silently
- If it DOES exist: show a brief diff and ask `[k]eep existing / [o]verwrite / [s]kip`

**Unix/Mac:**
```bash
mkdir -p ~/.claude/commands/
for f in "${CLAUDE_SRC}/commands/"*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  dest=~/.claude/commands/$fname
  if [ -f "$dest" ]; then
    echo ""
    echo "⚠️  Command conflict: $fname already exists."
    diff --unified=2 "$dest" "$f" | head -20 || true
    echo "[k]eep existing / [o]verwrite / [s]kip?"
    read -r choice
    case "$choice" in
      o|O) cp "$f" "$dest"; echo "Overwritten." ;;
      s|S) echo "Skipped." ;;
      *)   echo "Kept existing." ;;
    esac
  else
    cp "$f" "$dest"
    echo "Installed: $fname"
  fi
done
```

**Windows PowerShell:**
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\commands" -Force | Out-Null
Get-ChildItem "$claudeSrc\commands\*.md" | ForEach-Object {
    $dest = "$env:USERPROFILE\.claude\commands\$($_.Name)"
    if (Test-Path $dest) {
        Write-Host "⚠️  Conflict: $($_.Name) already exists."
        $choice = Read-Host "[k]eep existing / [o]verwrite / [s]kip?"
        if ($choice -match '^[oO]') { Copy-Item $_.FullName $dest -Force; Write-Host "Overwritten." }
        elseif ($choice -match '^[sS]') { Write-Host "Skipped." }
        else { Write-Host "Kept existing." }
    } else {
        Copy-Item $_.FullName $dest -Force
        Write-Host "Installed: $($_.Name)"
    }
}
```

### 6e. Restore settings.json

**If `~/.claude/settings.json` does not exist:** copy directly.

**If it does exist:** merge using Python, packed values take precedence, existing keys not in pack are preserved:

```bash
# Pass paths as environment variables — no hardcoded strings in the script
export CLAUDEPACK_SETTINGS="${CLAUDE_SRC}/settings.json"
export CLAUDEPACK_EXISTING=~/.claude/settings.json

python3 - <<'PYEOF'
import json, os

packed_path = os.environ['CLAUDEPACK_SETTINGS']
existing_path = os.environ['CLAUDEPACK_EXISTING']

with open(packed_path) as f:
    packed = json.load(f)
with open(existing_path) as f:
    existing = json.load(f)

conflicts = {k for k in existing if k in packed and existing[k] != packed[k]}
if conflicts:
    print("Settings conflicts (packed values will be used):")
    for k in sorted(conflicts):
        print(f"  {k}: {existing[k]!r}  →  {packed[k]!r}")

merged = {**existing, **packed}
with open(existing_path, 'w') as f:
    json.dump(merged, f, indent=2)
print("settings.json merged.")
PYEOF
```

If Python is unavailable, ask user: "Keep existing settings or replace with packed settings? [k/r]" and act accordingly.

### 6f. Restore CLAUDE.md (global)

If `claude/CLAUDE.md` exists in the pack:
- If `~/.claude/CLAUDE.md` does not exist: copy it
- If it does exist: show both file sizes and ask: `[k]eep existing / [o]verwrite / [m]erge — append packed content to existing`

### 6g. Cleanup temp claude staging

```bash
rm -rf "$CLAUDE_STAGE"                       # Unix
Remove-Item $claudeStage -Recurse -Force     # Windows
```

---

## Step 7: Git Notice (if .git was included)

Read `git_remote_origin` from the manifest. Do NOT touch any git files. Just inform:

```
ℹ️  Git history restored.
    Remote 'origin' is set to: <git_remote_origin>
    Preserved exactly as packed. To use a different remote:
    git remote set-url origin <new-url>
```

Skip this notice if `git_remote_origin` is null or `git_included` is false.

---

## Step 8: Cleanup Downloaded Zip

Ask:
```
Delete claudepack_download.zip to free disk space? [y/N]
```
Default is N (keep). Delete only on explicit `y`.

---

## Step 9: Final Handoff Instructions

Print this and nothing else after it:

```
╔══════════════════════════════════════════════════════════════════════╗
║  ✅ UNPACK COMPLETE                                                  ║
║                                                                      ║
║  Project  : <project_name>                                           ║
║  From     : <source_host> (<source_os>) · <packed_at date>           ║
║  Location : <full absolute destination path>                         ║
║                                                                      ║
║  Memory, commands, and settings are restored.                        ║
║  Claude will not know the difference.                                ║
║                                                                      ║
║  ── Two steps to continue your session: ──────────────────────────  ║
║                                                                      ║
║  1.  cd <destination path>                                           ║
║  2.  Restart Claude Code                                             ║
║                                                                      ║
║  That's it. You're back.                                             ║
╚══════════════════════════════════════════════════════════════════════╝
```
