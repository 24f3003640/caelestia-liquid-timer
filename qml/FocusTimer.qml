pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Focus timer state. Lives in services/ so it survives the popout closing.
Singleton {
    id: root

    readonly property var presets: [25, 50]
    // same file the old python timer used, so today's stats carry over
    readonly property string statsPath: `${Quickshell.env("HOME")}/.local/share/focus-timer/stats.json`

    property int duration: 25          // selected minutes
    property bool active: false        // a session exists (running or paused)
    property bool running: false
    property real remaining: 25 * 60   // seconds
    property real progressNow: 0       // 0..1, updated by the tick
    property double endMs: 0

    property string statsDate: ""
    property int sessionsToday: 0
    property int minutesToday: 0

    readonly property string timeString: {
        const s = Math.max(0, Math.ceil(remaining));
        return pad2(Math.floor(s / 60)) + ":" + pad2(s % 60);
    }

    function pad2(n: int): string {
        return n < 10 ? "0" + n : String(n);
    }

    function todayStr(): string {
        const d = new Date();
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
    }

    function rollStats(): void {
        const t = todayStr();
        if (statsDate !== t) {
            statsDate = t;
            sessionsToday = 0;
            minutesToday = 0;
        }
    }

    function saveStats(): void {
        const json = JSON.stringify({
            date: statsDate,
            sessions_today: sessionsToday,
            total_minutes: minutesToday
        }, null, 2);
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", statsPath, json]);
    }

    function setDuration(minutes: int): void {
        if (active)
            return;
        duration = minutes;
        remaining = minutes * 60;
    }

    function start(): void {
        rollStats();
        remaining = duration * 60;
        endMs = Date.now() + remaining * 1000;
        progressNow = 0;
        active = true;
        running = true;
    }

    function toggle(): void {
        if (!active) {
            start();
        } else if (running) {
            remaining = Math.max(0, (endMs - Date.now()) / 1000);
            running = false;
        } else {
            endMs = Date.now() + remaining * 1000;
            running = true;
        }
    }

    function reset(): void {
        running = false;
        active = false;
        remaining = duration * 60;
        progressNow = 0;
    }

    function tick(): void {
        remaining = Math.max(0, (endMs - Date.now()) / 1000);
        progressNow = 1 - remaining / (duration * 60);
        if (remaining <= 0)
            finish();
    }

    function finish(): void {
        rollStats();
        sessionsToday += 1;
        minutesToday += duration;
        saveStats();
        Quickshell.execDetached([
            "notify-send", "-u", "critical", "-a", "Focus Timer", "-i", "alarm-symbolic",
            "Focus session complete",
            `${duration} min done. Today: ${sessionsToday} sessions (${minutesToday} min).`
        ]);
        reset();
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    FileView {
        path: root.statsPath
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.statsDate = d.date ?? "";
                root.sessionsToday = d.sessions_today ?? 0;
                root.minutesToday = d.total_minutes ?? 0;
            } catch (e) {}
            root.rollStats();
        }
    }

    // keybinds: qs -c caelestia ipc call focusTimer toggle
    IpcHandler {
        target: "focusTimer"

        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            root.start();
        }

        function reset(): void {
            root.reset();
        }
    }
}
