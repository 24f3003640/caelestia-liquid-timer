#!/usr/bin/env bash
# Liquid focus timer for caelestia-shell
#   ./install.sh              install (safe to re-run)
#   ./install.sh --uninstall  remove the files and undo the patches
#
# Env overrides (for testing): SYS=/path/to/system/caelestia DEST=/path/to/user/copy
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS="${SYS:-/etc/xdg/quickshell/caelestia}"
DEST="${DEST:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}"

if [ "${1:-}" = "--uninstall" ]; then
  [ -d "$DEST" ] || { echo "nothing to uninstall: $DEST does not exist"; exit 0; }
  python3 "$HERE/scripts/patch.py" remove "$DEST"
  rm -f "$DEST/services/FocusTimer.qml" "$DEST/modules/bar/popouts/FocusChamber.qml"
  echo "removed. restart the shell:  pkill -x qs; caelestia shell -d"
  exit 0
fi

if [ ! -d "$DEST" ]; then
  [ -d "$SYS" ] || { echo "cannot find caelestia-shell at $SYS (set SYS=...)"; exit 1; }
  mkdir -p "$(dirname "$DEST")"
  cp -a "$SYS" "$DEST"
  echo "copied $SYS -> $DEST"
else
  echo "using existing copy at $DEST"
fi

install -m 644 "$HERE/qml/FocusTimer.qml"   "$DEST/services/FocusTimer.qml"
install -m 644 "$HERE/qml/FocusChamber.qml" "$DEST/modules/bar/popouts/FocusChamber.qml"
python3 "$HERE/scripts/patch.py" apply "$DEST"

cat <<'MSG'

done. restart the shell:  pkill -x qs; caelestia shell -d
optional keybind (hyprland):
  bind = SUPER, T, exec, qs -c caelestia ipc call focusTimer toggle
MSG
