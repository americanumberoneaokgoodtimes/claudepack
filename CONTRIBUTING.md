# Contributing

Bug reports, improvements, and platform-specific fixes are welcome.

## What's in scope

- Bug fixes in the shell commands or PowerShell blocks
- Better cross-platform compatibility
- New transfer methods (e.g. magic-wormhole, rsync over SSH)
- Improved size estimation accuracy
- Edge cases (symlinks, very long paths, special characters in project names)

## What's out of scope

- Changing the core two-command design (`/pack` / `/unpack`)
- Adding dependencies that aren't widely pre-installed
- GUI or web interface — this is a CLI tool

## How to submit

1. Fork the repo
2. Edit `commands/pack.md` and/or `commands/unpack.md`
3. Test by running `/pack` in a real Claude Code session
4. Open a PR with a clear description of what you changed and why

## Testing checklist

- [ ] `/pack` wizard completes without errors
- [ ] Zip file is created with correct internal structure (`project/`, `claude/`, `manifest.json`)
- [ ] `manifest.json` contains correct `zip_root_dir` value
- [ ] `/unpack <url>` downloads, validates, and extracts correctly
- [ ] Memory files land at the correct `~/.claude/projects/<hash>/memory/` path
- [ ] Restarting Claude Code in the unpacked folder loads the restored session
- [ ] Tested on: Windows / Mac / Linux (note which in your PR)
