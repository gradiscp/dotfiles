import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A terminal glyph that lights up (bar.urgent) while Claude Code sessions wait
// for a permission ("A" of the 2026-09-13 bar mockups; no count badge since
// 2026-10-21, the number is in the tooltip). The count comes from
// `claude-notify count`: herdr agents in "blocked", plus the last plain
// terminal that asked and was not visited since. A right-click mutes the
// toasts or turns them back on (`claude-notify quiet on|off`); the sound
// stays. SUPER+P (`claude-notify jump`) goes straight to the latest waiter.
//
// A badge in the glyph's corner (bar and panel) shows what is off: a
// crossed-out bell for muted toasts, else a muted speaker for sounds off.
//
// A click opens the panel (since 2026-10-21): every Claude session herdr
// knows, waiting ones first with what they ask for, a click on a row goes
// there; the toast switch (the same flag as the right-click) and the sound
// switch (`claude-notify sound on|off`). The panel polls `claude-notify status`
// once a second only while it is open - the glyph's `count` poll runs
// regardless. Same bones as the stock agents/tailscale panels: Panel root,
// BarIconButton, KeyboardPanel with j/k, Enter, Esc.
Panel {
  id: root
  moduleName: "gradiscp.claude-status"
  // Panel's own IpcHandler: `omarchy-shell gradiscp.claude-status toggle`.
  ipcTarget: "gradiscp.claude-status"

  property int waiting: 0
  property bool quiet: false
  property bool silent: false
  property var sessions: []
  // "seit 2 min" reads this instead of Date.now(), refreshed with each poll.
  property double nowMs: Date.now()
  // Keyboard cursor: a session row, or the toast switch at sessions.length.
  property int cursor: 0
  property bool cursorActive: false

  readonly property string notify: Quickshell.env("HOME") + "/.local/bin/claude-notify"
  readonly property color alertColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Commons.Color.foreground, 0.45)
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int waitingSessions: {
    var n = 0
    for (var i = 0; i < sessions.length; i++) if (sessions[i].status === "blocked") n++
    return n
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function setQuiet(on) {
    // Shown at once; the next poll reads the flag back.
    root.quiet = on
    Quickshell.execDetached([root.notify, "quiet", on ? "on" : "off"])
  }

  function setSilent(on) {
    root.silent = on
    Quickshell.execDetached([root.notify, "sound", on ? "off" : "on"])
  }

  function goTo(session) {
    if (!session) return
    Quickshell.execDetached([root.notify, session.kind === "window" ? "focus-window" : "focus", String(session.id)])
    root.close()
  }

  function moveCursor(dy) {
    root.cursorActive = true
    root.cursor = Math.max(0, Math.min(root.sessions.length + 1, root.cursor + dy))
  }

  function activateCursor() {
    if (!root.cursorActive) return
    if (root.cursor < root.sessions.length) root.goTo(root.sessions[root.cursor])
    else if (root.cursor === root.sessions.length) root.setQuiet(!root.quiet)
    else root.setSilent(!root.silent)
  }

  function statusWord(status) {
    if (status === "blocked") return "wartet"
    if (status === "working") return "arbeitet"
    if (status === "idle") return "bereit"
    if (status === "done") return "fertig"
    return "unbekannt"
  }

  function statusColor(status) {
    if (status === "blocked") return root.alertColor
    if (status === "working") return root.foreground
    return root.dim
  }

  function since(ms) {
    var minutes = Math.floor((root.nowMs - Number(ms)) / 60000)
    if (!(minutes >= 1)) return "gerade eben"
    if (minutes < 60) return "seit " + minutes + " min"
    return "seit " + Math.floor(minutes / 60) + " h"
  }

  function applyStatus(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { return }
    if (!data || !(data.sessions instanceof Array)) return
    root.nowMs = Date.now()
    root.sessions = data.sessions
    root.quiet = data.quiet === true
    root.silent = data.sound === false
    if (root.cursor > root.sessions.length + 1) root.cursor = root.sessions.length + 1
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  Process {
    id: countProc
    command: [root.notify, "count"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text).trim().split("\n")
        var n = parseInt(lines[0], 10)
        root.waiting = isFinite(n) && n > 0 ? n : 0
        root.quiet = lines.indexOf("quiet") > 0
        root.silent = lines.indexOf("silent") > 0
      }
    }
  }

  Process {
    id: statusProc
    command: [root.notify, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(String(text))
    }
  }

  // herdr offers no push event for agent state, so poll. One second
  // (2026-10-21, was five): the glyph stayed lit for seconds after a prompt
  // was answered, and with toasts muted it is the only visual signal. A poll
  // is about 12 ms (bash, herdr, jq; hyprctl only while a plain terminal waits).
  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!countProc.running) countProc.running = true
  }

  // The panel's own poll, about 20 ms, only while it is open.
  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-oct-terminal as \uf489 (the glyph is U+F489): the raw glyph got lost
    // in an edit once, and a tool write dropped the escape once (empty string,
    // icon gone) - after an edit, check that the `text:` line still has it.
    text: "\uf489"
    foreground: root.waiting > 0 ? root.alertColor : root.idleColor
    tooltipText: (root.waiting === 0 ? "Keine Claude-Session wartet"
      : (root.waiting === 1 ? "1 Claude-Session wartet" : root.waiting + " Claude-Sessions warten"))
      + (root.quiet ? " · Benachrichtigungen aus (Rechtsklick: an)"
                    : " · Rechtsklick: Benachrichtigungen aus")
      + (root.silent ? " · Ton aus" : "")
    onPressed: function(button) {
      if (button === Qt.RightButton) root.setQuiet(!root.quiet)
      else root.toggle()
    }

    QuietBadge {
      anchors { right: parent.right; bottom: parent.bottom; rightMargin: Style.space(1); bottomMargin: Style.space(2) }
      size: Math.round(Style.bar.iconFont * 0.6)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "m" || t === "M") root.setQuiet(!root.quiet)
        else if (t === "t" || t === "T") root.setSilent(!root.silent)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: glyph · Claude Code · how many wait ----------
          PanelHero {
            width: parent.width
            title: "Claude Code"
            meta: root.waitingSessions === 0 ? "Keine Session wartet"
              : (root.waitingSessions === 1 ? "1 Session wartet" : root.waitingSessions + " Sessions warten")
            detail: root.sessions.length === 0 ? ""
              : (root.sessions.length === 1 ? "1 Session" : root.sessions.length + " Sessions")
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: button.text
                color: root.waitingSessions > 0 ? root.alertColor : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display

                Behavior on color { ColorAnimation { duration: 160 } }

                QuietBadge {
                  anchors { right: parent.right; bottom: parent.bottom; rightMargin: -Style.space(8); bottomMargin: -Style.space(4) }
                  size: Math.round(Style.font.display * 0.45)
                  color: "transparent"
                }
              }
            }
          }

          // ---------- Sessions ----------
          PanelSeparator { foreground: root.foreground }

          Column {
            id: sessionSection
            width: parent.width
            spacing: Style.spacing.xs

            PanelSectionHeader {
              width: parent.width
              text: "SESSIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.sessions.length === 0
              width: parent.width
              topPadding: Style.spacing.md
              bottomPadding: Style.spacing.md
              text: "Keine Claude-Session in herdr."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.sessions

              SessionRow {
                required property var modelData
                required property int index
                width: sessionSection.width
                session: modelData
                rowIndex: index
              }
            }
          }

          // ---------- Toasts on/off ----------
          PanelSeparator { foreground: root.foreground }

          Toggle {
            width: parent.width
            label: "Benachrichtigungen"
            description: root.quiet ? "Aus: kein Toast, das Symbol leuchtet weiter"
                                    : "Toast, wenn Claude eine Genehmigung braucht"
            checked: !root.quiet
            hasCursor: root.cursorActive && root.cursor === root.sessions.length
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.setQuiet(!root.quiet)
            onHovered: function(isHovered) {
              if (!isHovered) return
              root.cursorActive = true
              root.cursor = root.sessions.length
            }
          }

          Toggle {
            width: parent.width
            label: "Ton"
            description: root.silent ? "Aus: kein Ton bei Genehmigung und wenn Claude fertig ist"
                                     : "Bei Genehmigung und wenn Claude fertig ist"
            checked: !root.silent
            hasCursor: root.cursorActive && root.cursor === root.sessions.length + 1
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.setSilent(!root.silent)
            onHovered: function(isHovered) {
              if (!isHovered) return
              root.cursorActive = true
              root.cursor = root.sessions.length + 1
            }
          }
        }
      }
    }
  }

  // One Claude session: status dot, title, what it does or asks for, and the
  // project on the right. A click goes to that pane (or plain terminal).
  component SessionRow: CursorSurface {
    id: row
    property var session: null
    property int rowIndex: 0

    readonly property string status: session ? String(session.status || "") : ""
    readonly property bool blocked: status === "blocked"
    readonly property string detail: {
      if (!session) return ""
      if (blocked) {
        var ask = String(session.ask || "")
        var when = session.asked_ms > 0 ? root.since(session.asked_ms) : ""
        if (ask === "") return "Wartet auf eine Antwort" + (when !== "" ? " · " + when : "")
        return ask + (when !== "" ? " · " + when : "")
      }
      return root.statusWord(status)
    }

    hasCursor: root.cursorActive && root.cursor === rowIndex
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.lg * 2

    Row {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.spacing.xl

      Rectangle {
        width: Style.space(8)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.statusColor(row.status)
        opacity: row.status === "done" ? 0.5 : 1
      }

      Column {
        width: parent.width - parent.spacing * 2 - Style.space(8) - projectText.width
        spacing: Style.spacing.xxs
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: row.session && String(row.session.title || "") !== "" ? String(row.session.title) : "Ohne Titel"
          color: row.blocked ? root.foreground : (row.status === "working" ? root.foreground : root.dim)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: row.blocked
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: row.detail
          color: row.blocked ? root.alertColor : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        id: projectText
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: row.session ? String(row.session.project || "") : ""
        width: Math.min(implicitWidth, Style.space(96))
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.cursor = row.rowIndex
      }
      onClicked: root.goTo(row.session)
    }
  }

  // Toasts muted: a crossed-out bell (nf-fa-bell_slash, U+F1F6); else sounds
  // off: a muted speaker (nf-oct-mute, U+F466). On a disc of the bar's
  // background, so it reads as a badge on top of the glyph.
  component QuietBadge: Rectangle {
    property real size: Style.space(10)
    visible: root.quiet || root.silent
    z: 10
    width: size + Style.space(4)
    height: width
    radius: width / 2
    color: root.bar ? root.bar.background : Commons.Color.background

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.quiet ? "\uf1f6" : "\uf466"
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      font.family: root.fontFamily
      font.pixelSize: parent.size
    }
  }
}
