# Spicetify auto-update (added 2026-10-16)

Spicetify has no built-in auto-update, so a launchd agent runs a script daily.

## Pieces

- `~/.config/spicetify/auto-update.sh` (tracked in this repo)
  ```zsh
  spicetify upgrade -n
  spicetify backup apply -n
  ```
- `~/Library/LaunchAgents/com.spicetify.autoupdate.plist` (NOT in the repo)
  - Label `com.spicetify.autoupdate`
  - Runs the script at login (`RunAtLoad`) and daily at 12:00
  - stdout/stderr -> `/tmp/spicetify-autoupdate.log`

Spicetify itself is installed via the official install script in `~/.spicetify`
(not Homebrew). Config is `config-xpui.ini` here; only `marketplace` is used.

## Why `-n` on BOTH commands

`-n` / `--no-restart` prevents spicetify from killing/launching Spotify.
Without it the job launches Spotify every day even when it was closed.

- `spicetify upgrade` without `-n`, when already up to date, runs its own
  "fix it for you" `backup apply` step which restarts Spotify. `-n` skips it.
- `spicetify backup apply` without `-n` always restarts Spotify.

## Expected behaviour

- Nothing changed: `backup apply` prints "After clearing backup, Spotify cannot
  be backed up again" and exits 1. This is normal and harmless (no-op).
- Spotify updated: client is stock again, so spicetify re-backs-up and
  re-applies the theme on disk. Takes effect next time Spotify is opened.
- New spicetify release: `upgrade -n` installs it.

## Managing

```zsh
launchctl kickstart gui/$(id -u)/com.spicetify.autoupdate   # run now
launchctl bootout   gui/$(id -u)/com.spicetify.autoupdate   # disable
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spicetify.autoupdate.plist  # enable
```

Plist contents, in case it needs recreating on a new machine:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.spicetify.autoupdate</string>
  <key>ProgramArguments</key>
  <array><string>/Users/julien/.config/spicetify/auto-update.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/spicetify-autoupdate.log</string>
  <key>StandardErrorPath</key><string>/tmp/spicetify-autoupdate.log</string>
</dict>
</plist>
```

## Git: `[Backup] version` line is filtered out

`config-xpui.ini` has a `version = ...` line under `[Backup]` that changes every
time Spotify updates. `.gitattributes` routes the file through a clean filter that
blanks that value on commit, so it never shows as a diff. The filter definition
is local git config, so on a fresh clone run once:

```zsh
git config filter.spicetify-backup-version.clean "sed -E 's/^(version *= *).*/\1/'"
git config filter.spicetify-backup-version.smudge cat
```

A blank version just means "no backup yet" to spicetify; `spicetify backup apply`
fixes it on the next run.
