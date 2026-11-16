#!/usr/bin/env bash
# Install EasyMove for Hammerspoon.
#
#   ./install.sh               link the module into ~/.hammerspoon and enable it in init.lua
#   ./install.sh --uninstall   remove the link and the init.lua block
#   ./install.sh --copy        copy the files instead of symlinking
#
# Environment: HS_DIR overrides the Hammerspoon config directory (default ~/.hammerspoon).

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/easymove"
HS_DIR="${HS_DIR:-$HOME/.hammerspoon}"
DEST="$HS_DIR/easymove"
INIT="$HS_DIR/init.lua"
BEGIN_MARK="-- >>> easymove >>>"
END_MARK="-- <<< easymove <<<"

MODE="link"
ACTION="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) ACTION="uninstall" ;;
    --copy) MODE="copy" ;;
    -h|--help)
      echo "Usage: ./install.sh [--uninstall | --copy]"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

has_block() { [ -f "$INIT" ] && grep -qF -e "$BEGIN_MARK" "$INIT"; }

backup_init() {
  if [ -f "$INIT" ]; then
    local backup="$INIT.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$INIT" "$backup"
    echo "  backed up init.lua -> $backup"
  fi
}

if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling EasyMove from $HS_DIR"
  if has_block; then
    backup_init
    sed -i '' "/$BEGIN_MARK/,/$END_MARK/d" "$INIT"
    echo "  removed block from init.lua"
  fi
  if [ -L "$DEST" ]; then
    rm "$DEST"; echo "  removed symlink $DEST"
  elif [ -d "$DEST" ]; then
    echo "  $DEST is a real directory; remove manually if desired."
  fi
  echo "Reload Hammerspoon (menu bar icon > Reload Config) to finish."
  exit 0
fi

if [ ! -d "$SRC" ]; then
  echo "Cannot find module sources at $SRC" >&2
  exit 1
fi

echo "Installing EasyMove into $HS_DIR"
mkdir -p "$HS_DIR"

# 1. Put the module where `require("easymove")` finds it.
if [ -L "$DEST" ]; then
  rm "$DEST"
elif [ -e "$DEST" ]; then
  echo "  $DEST already exists and is not a symlink. Move it away and re-run." >&2
  exit 1
fi

if [ "$MODE" = "copy" ]; then
  cp -R "$SRC" "$DEST"
  echo "  copied module to $DEST"
else
  ln -s "$SRC" "$DEST"
  echo "  linked $DEST -> $SRC"
fi

# 2. Enable it from init.lua
if has_block; then
  echo "  init.lua already enables EasyMove"
else
  backup_init
  {
    [ -s "$INIT" ] && printf '\n'
    printf '%s\n' "$BEGIN_MARK"
    printf '%s\n' 'local ok_em, em = pcall(require, "easymove")'
    printf '%s\n' 'if ok_em then'
    printf '%s\n' '  em.start()'
    printf '%s\n' 'else'
    printf '%s\n' '  hs.alert.show("EasyMove failed to load: " .. tostring(em), 6)'
    printf '%s\n' 'end'
    printf '%s\n' "$END_MARK"
  } >> "$INIT"
  echo "  added EasyMove block to init.lua"
fi

echo "Done! Reload Hammerspoon to start using EasyMove."
