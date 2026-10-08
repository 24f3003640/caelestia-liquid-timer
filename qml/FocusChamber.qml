pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// The hover popout IS the chamber: it bleeds out over the popout's own padding,
// the liquid rises as you focus, and anything the liquid covers is redrawn in a
// contrasting ink (second copy of the UI, masked by the wave shape).
Item {
    id: root

    // tweak if the corners don't line up with the shell's popout panel
    readonly property real cornerRadius: Tokens.rounding.large
    readonly property real pad: Tokens.padding.large

    readonly property real baseLevel: 0.2
    readonly property real cw: implicitWidth + pad * 2
    readonly property real ch: implicitHeight + pad * 2

    readonly property bool paused: FocusTimer.active && !FocusTimer.running
    readonly property color liquid: paused ? Colours.palette.m3tertiary : Colours.palette.m3primary
    readonly property color liquidInk: paused ? Colours.palette.m3onTertiary : Colours.palette.m3onPrimary
    readonly property color baseInk: Colours.palette.m3onSurface

    property real level: baseLevel
    property real t: 0
    property string hovered
    property var bubbles: initBubbles()

    readonly property real surfaceY: ch * (1 - level)
    readonly property real amp: Math.min(12, Math.max(5, (ch - surfaceY) * 0.04))

    implicitWidth: 280
    implicitHeight: 400

    function setHover(name: string, on: bool): void {
        if (on)
            hovered = name;
        else if (hovered === name)
            hovered = "";
    }

    function newBubble(scatter: bool): var {
        return {
            x: 16 + Math.random() * (cw - 32),
            y: scatter ? ch * (0.4 + Math.random() * 0.6) : ch - 4 - Math.random() * 16,
            r: 2 + Math.random() * 3,
            s: 0.6 + Math.random() * 1.4,
            p: Math.random() * 6.28
        };
    }

    function initBubbles(): var {
        const a = [];
        for (let i = 0; i < 14; i++)
            a.push(newBubble(true));
        return a;
    }

    function trace(ctx: var, phase: real, a1: real, a2: real, dy: real, w: real, h: real): void {
        ctx.beginPath();
        ctx.moveTo(0, h + 4);
        for (let x = 0; x <= w + 4; x += 4)
            ctx.lineTo(x, surfaceY + dy + Math.sin(x * 0.022 + phase) * a1 + Math.sin(x * 0.045 + phase * 1.2) * a2);
        ctx.lineTo(w + 4, h + 4);
        ctx.closePath();
    }

    FrameAnimation {
        running: true
        onTriggered: {
            const dt = Math.min(frameTime, 0.1);
            root.t += dt;

            const target = root.baseLevel + FocusTimer.progressNow * (1 - root.baseLevel);
            root.level += (target - root.level) * (1 - Math.exp(-dt * 4));

            for (const b of root.bubbles) {
                b.y -= b.s * 60 * dt;
                b.p += 5 * dt;
                if (b.y < root.surfaceY + 4)
                    Object.assign(b, root.newBubble(false));
            }

            liquidCanvas.requestPaint();
            maskCanvas.requestPaint();
        }
    }

    Item {
        id: chamber

        anchors.fill: parent
        anchors.margins: -root.pad

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: Colours.tPalette.m3surfaceContainer
        }

        // normal ink, interactive
        ChamberUI {
            anchors.fill: parent
            ink: root.baseInk
            interactive: true
        }

        // the liquid
        Canvas {
            id: liquidCanvas

            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const base = root.liquid;
                const amp = root.amp;

                ctx.save();
                ctx.beginPath();
                ctx.roundedRect(0, 0, w, h, root.cornerRadius, root.cornerRadius);
                ctx.clip();

                function fillLayer(phase, a1, a2, dy, c0, c1) {
                    const g = ctx.createLinearGradient(0, root.surfaceY, 0, h);
                    g.addColorStop(0, c0);
                    g.addColorStop(1, c1);
                    root.trace(ctx, phase, a1, a2, dy, w, h);
                    ctx.fillStyle = g;
                    ctx.fill();
                }

                fillLayer(root.t * 0.6, amp * 0.5, amp * 0.3, 10,
                          Qt.alpha(Qt.darker(base, 1.6), 0.8), Qt.alpha(Qt.darker(base, 2.1), 0.92));
                fillLayer(root.t * 1.05, amp * 0.65, amp * 0.4, 5,
                          Qt.alpha(Qt.darker(base, 1.25), 0.85), Qt.alpha(Qt.darker(base, 1.5), 0.94));
                // front layer is opaque so the normal-ink UI never ghosts through
                fillLayer(root.t * 1.5, amp * 0.8, amp * 0.5, 0,
                          Qt.lighter(base, 1.06), Qt.darker(base, 1.12));

                // foam line
                ctx.beginPath();
                for (let x = 0; x <= w + 4; x += 4) {
                    const y = root.surfaceY + Math.sin(x * 0.022 + root.t * 1.5) * amp * 0.8 + Math.sin(x * 0.045 + root.t * 1.5 * 1.2) * amp * 0.5;
                    if (x === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.strokeStyle = Qt.alpha(Qt.lighter(base, 1.7), 0.8);
                ctx.lineWidth = 1.8;
                ctx.stroke();

                // bubbles
                for (const b of root.bubbles) {
                    if (b.y <= root.surfaceY + 6)
                        continue;
                    const bx = b.x + Math.sin(b.p) * 3;
                    ctx.fillStyle = Qt.alpha(Qt.lighter(base, 2.2), 0.5);
                    ctx.beginPath();
                    ctx.arc(bx, b.y, b.r, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.8);
                    ctx.beginPath();
                    ctx.arc(bx - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.restore();
            }
        }

        // mask = exactly the front wave region
        Item {
            id: maskItem

            anchors.fill: parent
            visible: false
            layer.enabled: true

            Canvas {
                id: maskCanvas

                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.save();
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, width, height, root.cornerRadius, root.cornerRadius);
                    ctx.clip();
                    root.trace(ctx, root.t * 1.5, root.amp * 0.8, root.amp * 0.5, 0, width, height);
                    ctx.fillStyle = "black";
                    ctx.fill();
                    ctx.restore();
                }
            }
        }

        // inverted ink copy of the UI
        ChamberUI {
            id: invUi

            anchors.fill: parent
            ink: root.liquidInk
            visible: false
            layer.enabled: true
        }

        // show the inverted copy only where the liquid is
        MultiEffect {
            anchors.fill: parent
            source: invUi
            maskEnabled: true
            maskSource: maskItem
        }
    }

    // ---------------------------------------------------------------- ui
    component ChamberUI: Item {
        id: ui

        required property color ink
        property bool interactive: false

        readonly property int pct: Math.round(FocusTimer.progressNow * 100)
        readonly property bool idle: !FocusTimer.active

        Item {
            id: inner

            anchors.fill: parent
            anchors.margins: root.pad

            // status
            Text {
                y: 24
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
                font.family: Tokens.font.body.small.family
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 3
                color: Qt.alpha(ui.ink, 0.8)
                text: ui.idle ? "READY" : root.paused ? "PAUSED" : FocusTimer.duration >= 50 ? "DEEP FOCUS" : "FOCUS"
            }

            // time, fixed-width cells so digits never jitter
            Row {
                y: 54
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: FocusTimer.timeString.split("")

                    Item {
                        id: cell

                        required property string modelData

                        width: modelData === ":" ? 20 : 40
                        height: 80

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.family: Tokens.font.body.small.family
                            font.pixelSize: 64
                            font.weight: Font.Light
                            color: ui.ink
                            text: cell.modelData
                        }
                    }
                }
            }

            // sub line
            Text {
                y: 140
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
                font.family: Tokens.font.body.small.family
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                color: Qt.alpha(ui.ink, 0.8)
                text: ui.idle ? `${FocusTimer.duration} minute session` : root.paused ? `paused at ${ui.pct}%` : `${ui.pct}% filled`
            }

            // duration chips
            Row {
                y: 188
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: FocusTimer.presets

                    Rectangle {
                        id: chip

                        required property int modelData
                        readonly property bool sel: modelData === FocusTimer.duration
                        readonly property bool hov: root.hovered === `d${modelData}` && ui.idle

                        width: 92
                        height: 32
                        radius: height / 2
                        color: sel ? Qt.alpha(ui.ink, 0.18) : hov ? Qt.alpha(ui.ink, 0.1) : "transparent"
                        border.width: 1.2
                        border.color: Qt.alpha(ui.ink, sel ? (ui.idle ? 0.9 : 0.45) : (ui.idle ? 0.4 : 0.18))

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.family: Tokens.font.body.small.family
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ui.ink
                            opacity: ui.idle ? (chip.sel ? 1 : 0.75) : 0.35
                            text: `${chip.modelData} min`
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: ui.interactive && ui.idle
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: root.setHover(`d${chip.modelData}`, containsMouse)
                            onClicked: FocusTimer.setDuration(chip.modelData)
                        }
                    }
                }
            }

            // today
            Text {
                y: 240
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
                font.family: Tokens.font.body.small.family
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.8
                color: Qt.alpha(ui.ink, 0.75)
                text: `today  ·  ${FocusTimer.sessionsToday} session${FocusTimer.sessionsToday === 1 ? "" : "s"}  ·  ${FocusTimer.minutesToday} min`
            }

            // controls
            Row {
                y: 300
                spacing: 16
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    id: playBtn

                    width: 64
                    height: 64
                    radius: 32
                    color: root.hovered === "play" ? Qt.alpha(ui.ink, 0.16) : "transparent"
                    border.width: 1.6
                    border.color: Qt.alpha(ui.ink, 0.85)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: FocusTimer.running ? "pause" : "play_arrow"
                        color: ui.ink
                        fontStyle: Tokens.font.icon.large
                        fill: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: ui.interactive
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.setHover("play", containsMouse)
                        onClicked: FocusTimer.toggle()
                    }
                }

                Rectangle {
                    id: resetBtn

                    anchors.verticalCenter: playBtn.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: root.hovered === "reset" ? Qt.alpha(ui.ink, 0.16) : "transparent"
                    border.width: 1.3
                    border.color: Qt.alpha(ui.ink, 0.5)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "restart_alt"
                        color: ui.ink
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: ui.interactive
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: root.setHover("reset", containsMouse)
                        onClicked: FocusTimer.reset()
                    }
                }
            }
        }
    }
}
