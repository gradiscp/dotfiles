import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A shield (meant for the tray drawer) that starts the checks of
// `security-audit`: all of them in a row, or one. A click opens the panel; a
// row there opens a floating terminal running that check and shows the
// check's last result. The shield lights up (bar.urgent) while a last result
// holds a finding and is drawn in full while a check runs.
//
// Everything it shows comes from $XDG_STATE_HOME/security-audit/state.json,
// which only the script writes (it replaces the file, so a timer re-reads it
// besides the file watch: every 2 s while the panel is open or a check runs,
// else every 30 s). Same bones as gradiscp.ai-status.
Panel {
  id: root
  moduleName: "gradiscp.security"
  // Panel's own IpcHandler: `omarchy-shell gradiscp.security toggle`.
  ipcTarget: "gradiscp.security"

  property string running: ""
  property var checks: ({})
  property double nowS: Date.now() / 1000
  property int cursor: 0
  property bool cursorActive: false

  readonly property string script: Quickshell.env("HOME") + "/.local/bin/security-audit"
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/security-audit/state.json"
  readonly property var rows: [
    { id: "all", title: "Alles prüfen", what: "Pakete, Projekte und Viren nacheinander" },
    { id: "packages", title: "Pakete", what: "Installierte Pakete mit bekannter Lücke" },
    { id: "projects", title: "Projekte", what: "Abhängigkeiten unter ~/Projects (osv.dev)" },
    { id: "viruses", title: "Viren", what: "Downloads und eingesteckte USB-Sticks" }
  ]
  readonly property int findings: {
    var n = 0
    for (var k in checks) if (checks[k] && checks[k].findings > 0) n += checks[k].findings
    return n
  }
  readonly property double lastRun: {
    var t = 0
    for (var k in checks) if (checks[k] && checks[k].time > t) t = checks[k].time
    return t
  }

  readonly property color alertColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Commons.Color.foreground, 0.45)
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function title(id) {
    for (var i = 0; i < root.rows.length; i++) if (root.rows[i].id === id) return root.rows[i].title
    return id
  }

  function ago(t) {
    var minutes = Math.floor((root.nowS - Number(t)) / 60)
    if (!(minutes >= 1)) return "gerade eben"
    if (minutes < 60) return "vor " + minutes + " min"
    var hours = Math.floor(minutes / 60)
    if (hours < 48) return "vor " + hours + " h"
    return "vor " + Math.floor(hours / 24) + " Tagen"
  }

  function result(id) {
    var c = root.checks[id]
    if (!c) return "noch nie geprüft"
    return String(c.summary) + " · " + root.ago(c.time)
  }

  // The script decides whether a check may start (its lock); a busy panel only
  // greys the rows, so a "running" left behind can never block a new run.
  function start(id) {
    // Shown at once (and the fast re-read starts); the script's own state
    // takes over with the next read, also when it refuses to run.
    if (root.running === "") root.running = id
    Quickshell.execDetached([root.script, "open", id])
    root.close()
  }

  function moveCursor(dy) {
    root.cursorActive = true
    root.cursor = Math.max(0, Math.min(root.rows.length - 1, root.cursor + dy))
  }

  function activateCursor() {
    if (root.cursorActive) root.start(root.rows[root.cursor].id)
  }

  function applyState(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { data = {} }
    root.nowS = Date.now() / 1000
    root.running = data && data.running ? String(data.running) : ""
    root.checks = data && data.checks ? data.checks : ({})
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    stateFile.reload()
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyState(text())
    onLoadFailed: root.applyState("{}")
  }

  Timer {
    interval: root.opened || root.running !== "" ? 2000 : 30000
    running: true
    repeat: true
    onTriggered: stateFile.reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-shield as , written as an escape so an edit cannot drop it.
    text: ""
    foreground: root.findings > 0 ? root.alertColor : (root.running !== "" ? root.foreground : root.idleColor)
    tooltipText: root.running !== "" ? "Sicherheits-Check läuft: " + root.title(root.running)
      : (root.findings > 0 ? "Sicherheits-Check: " + root.findings + " Fund(e)" : "Sicherheits-Checks")
    onPressed: function(button) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Sicherheit"
          meta: root.running !== "" ? "Läuft: " + root.title(root.running)
            : (root.findings > 0 ? root.findings + " Fund(e) beim letzten Check"
              : (root.lastRun > 0 ? "Nichts gefunden" : "Noch nicht geprüft"))
          detail: root.lastRun > 0 ? "Zuletzt " + root.ago(root.lastRun) : ""
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: button.text
              color: root.findings > 0 ? root.alertColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          id: checkSection
          width: parent.width
          spacing: Style.spacing.xs

          PanelSectionHeader {
            width: parent.width
            text: "PRÜFEN"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.rows

            CheckRow {
              required property var modelData
              required property int index
              width: checkSection.width
              check: modelData
              rowIndex: index
            }
          }
        }
      }
    }
  }

  // One check: what it looks at, its last result (or "läuft"), a click starts
  // it. Greyed out while any check runs: one at a time.
  component CheckRow: CursorSurface {
    id: row
    property var check: null
    property int rowIndex: 0

    readonly property string checkId: check ? String(check.id) : ""
    readonly property bool busy: root.running !== ""
    readonly property bool runningHere: root.running === checkId
    readonly property bool found: root.checks[checkId] !== undefined && root.checks[checkId].findings > 0

    hasCursor: root.cursorActive && root.cursor === rowIndex
    foreground: root.foreground
    opacity: busy && !runningHere ? 0.5 : 1
    implicitHeight: rowContent.implicitHeight + Style.spacing.lg * 2

    Column {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.spacing.xxs

      // Title on the left, the last result (or "läuft") on the right.
      Item {
        width: parent.width
        implicitHeight: titleText.implicitHeight

        Text {
          id: titleText
          textFormat: Text.PlainText
          anchors.left: parent.left
          width: parent.width - resultText.width - Style.spacing.xl
          text: row.check ? String(row.check.title) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: row.checkId === "all"
          elide: Text.ElideRight
        }

        Text {
          id: resultText
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: titleText.verticalCenter
          text: row.runningHere ? "läuft …" : (row.checkId === "all" ? "" : root.result(row.checkId))
          width: Math.min(implicitWidth, parent.width * 0.6)
          color: row.found || row.runningHere ? root.alertColor : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideLeft
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: row.check ? String(row.check.what) : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
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
      onClicked: root.start(row.checkId)
    }
  }
}
