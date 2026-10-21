#!/bin/zsh
# Daily spicetify update that never launches Spotify.
#
# Do NOT use `spicetify upgrade` here: when it actually installs a new version it
# re-execs the new binary with a plain `backup apply` (no -n), and that child
# restarts Spotify even if it was closed. So we upgrade the binary ourselves the
# same way spicetify does (download the release tarball, untar into ~/.spicetify)
# and keep -n on every spicetify call.
set -u
SP_DIR="$HOME/.spicetify"
export PATH="$SP_DIR:$PATH"

current=$(spicetify -v 2>/dev/null)
latest=$(curl -fsSL https://api.github.com/repos/spicetify/cli/releases/latest \
  | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')

if [[ -z "$latest" ]]; then
  echo "spicetify: cannot fetch latest release info, skipping binary upgrade"
elif [[ "$latest" != "$current" ]]; then
  case "$(uname -m)" in arm64) arch=arm64 ;; *) arch=amd64 ;; esac
  url="https://github.com/spicetify/cli/releases/download/v${latest}/spicetify-${latest}-darwin-${arch}.tar.gz"
  tmp=$(mktemp -t spicetify-upgrade)
  if curl -fsSL "$url" -o "$tmp" && tar -xzf "$tmp" -C "$SP_DIR"; then
    rm -f "$tmp"
    echo "spicetify: upgraded ${current:-?} -> $latest"
    # Re-patch with the new version. If Spotify is already patched, backup
    # refuses, so restore the stock client first (what `upgrade` does itself).
    spicetify backup apply -n || spicetify restore backup apply -n
    exit
  fi
  rm -f "$tmp"
  echo "spicetify: upgrade to $latest failed, keeping $current"
else
  echo "spicetify v$current is up to date"
fi

# Re-apply if Spotify updated itself (client is stock again). When nothing
# changed this prints "cannot be backed up again" and exits 1: normal no-op.
spicetify backup apply -n
