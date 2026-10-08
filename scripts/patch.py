#!/usr/bin/env python3
"""Apply / remove the two small patches the liquid timer needs inside a caelestia-shell copy.

usage: patch.py apply|remove <path-to-caelestia-copy>
"""
import sys
import pathlib

CONTENT_MARKER = '        Popout {\n            name: "kblayout"'
CONTENT_BLOCK = (
    '        Popout {\n'
    '            name: "focustimer"\n'
    '            sourceComponent: FocusChamber {}\n'
    '        }\n\n'
)

ICONS_MARKER = '    }\n\n    component EntryWrapper: Item {'
ICONS_BLOCK = '''
        // focus timer (hover opens the liquid chamber popout)
        Item {
            readonly property string name: "focustimer"

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: root.spacing / 2

            implicitWidth: timerIcon.implicitWidth
            implicitHeight: timerIcon.implicitHeight

            MaterialIcon {
                id: timerIcon

                animate: true
                text: FocusTimer.running ? "hourglass_top" : FocusTimer.active ? "pause_circle" : "timer"
                color: FocusTimer.running ? Colours.palette.m3primary : root.colour
            }
        }
'''


def patch(path, marker, block, tag, mode):
    txt = path.read_text()
    present = tag in txt
    if mode == "apply":
        if present:
            print(f"{path.name}: already patched")
            return
        if txt.count(marker) != 1:
            sys.exit(f"{path.name}: expected anchor not found (shell version differs?). "
                     "See 'Manual install' in the README.")
        path.write_text(txt.replace(marker, block + marker, 1))
        print(f"{path.name}: patched")
    else:
        if not present:
            print(f"{path.name}: nothing to remove")
            return
        if block not in txt:
            sys.exit(f"{path.name}: patch was edited by hand, remove it manually")
        path.write_text(txt.replace(block, "", 1))
        print(f"{path.name}: restored")


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("apply", "remove"):
        sys.exit(__doc__)
    mode, dest = sys.argv[1], pathlib.Path(sys.argv[2])
    patch(dest / "modules/bar/popouts/Content.qml", CONTENT_MARKER, CONTENT_BLOCK, 'name: "focustimer"', mode)
    patch(dest / "modules/bar/components/StatusIcons.qml", ICONS_MARKER, ICONS_BLOCK, '"focustimer"', mode)


main()
