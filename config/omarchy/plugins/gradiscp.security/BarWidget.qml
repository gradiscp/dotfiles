import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A shield (meant for the tray drawer) that starts the checks of
// `security-audit` in the background: all of them, or one, each with a choice
// of how far it reaches (chips), up to "Komplett" = the whole computer. The
// row's play button starts it, the same button stops a running one; the
// script sends a toast when done, and "Bericht" opens the last run's output.
// The shield lights up (bar.urgent) while a last result holds a finding and
// is drawn in full while a check runs.
//
// Everything it shows comes from $XDG_STATE_HOME/security-audit/state.json,
// which only the script writes (it replaces the file, so a timer re-reads it
// besides the file watch: every 2 s while the panel is open or a check runs,
// else every 30 s). The chips start at each check's last used scope. Keys:
// j/k row, h/l scope, Enter start/stop. Same bones as gradiscp.ai-status.
Panel {
  id: root
  moduleName: "gradiscp.security"
  // Panel's own IpcHandler: `omarchy-shell gradiscp.security toggle`.
  ipcTarget: "gradiscp.security"

  property var running: null
  property var checks: ({})
  property var choice: ({ all: "quick", packages: "fixable", projects: "projects", viruses: "downloads" })
  property double nowS: Date.now() / 1000
  property int cursor: 0
  property bool cursorActive: false

  readonly property string script: Quickshell.env("HOME") + "/.local/bin/security-audit"
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/security-audit/state.json"
  readonly property string runningCheck: running && running.check ? String(running.check) : ""
  readonly property var rows: [
    { id: "all", title: "Alles prüfen", options: [
      { value: "quick", label: "Schnell", what: "Pakete, ~/Projects, Downloads und USB-Sticks" },
      { value: "full", label: "Komplett", what: "Alle Pakete, Home + Images, ganzer Rechner" }
    ] },
    { id: "packages", title: "Pakete", options: [
      { value: "fixable", label: "Mit Update", what: "Pakete mit Lücke, die ein Update behebt" },
      { value: "all", label: "Alle", what: "Auch Lücken ohne Fix bisher auflisten" }
    ] },
    { id: "projects", title: "Projekte", options: [
      { value: "projects", label: "Projekte", what: "Abhängigkeiten unter ~/Projects (osv.dev)" },
      { value: "home", label: "Home", what: "Ganz ~, auch per mise installierte Tools" },
      { value: "images", label: "+ Images", what: "Home und alle lokalen Docker-Images" }
    ] },
    { id: "viruses", title: "Viren", options: [
      { value: "downloads", label: "Downloads", what: "Downloads und eingesteckte USB-Sticks" },
      { value: "home", label: "Home", what: "Der ganze Home-Ordner und USB-Sticks" },
      { value: "computer", label: "Ganzer PC", what: "Alles Lesbare auf dem Rechner, dauert lange" }
    ] }
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

  function rowOf(id) {
    for (var i = 0; i < root.rows.length; i++) if (root.rows[i].id === id) return root.rows[i]
    return null
  }

  function title(id) {
    var row = root.rowOf(id)
    return row ? row.title : id
  }

  function option(id, value) {
    var row = root.rowOf(id)
    if (!row) return null
    for (var i = 0; i < row.options.length; i++) if (row.options[i].value === value) return row.options[i]
    return null
  }

  function ago(t, prefix) {
    var minutes = Math.floor((root.nowS - Number(t)) / 60)
    if (!(minutes >= 1)) return prefix === "seit" ? "gerade gestartet" : "gerade eben"
    if (minutes < 60) return prefix + " " + minutes + " min"
    var hours = Math.floor(minutes / 60)
    if (hours < 48) return prefix + " " + hours + " h"
    return prefix + " " + Math.floor(hours / 24) + " Tagen"
  }

  function result(id) {
    if (root.runningCheck === id) return "läuft, " + root.ago(root.running.since, "seit")
    if (id === "all") return ""
    var c = root.checks[id]
    if (!c) return "noch nie geprüft"
    return String(c.summary) + " · " + root.ago(c.time, "vor")
  }

  function choose(id, value) {
    var next = Object.assign({}, root.choice)
    next[id] = value
    root.choice = next
  }

  function stepChoice(id, dx) {
    var row = root.rowOf(id)
    if (!row) return
    var i = 0
    for (; i < row.options.length; i++) if (row.options[i].value === root.choice[id]) break
    i = Math.max(0, Math.min(row.options.length - 1, i + dx))
    root.choose(id, row.options[i].value)
  }

  // The script decides whether a check may start (its unit and lock) and says
  // so in a toast; a busy panel only greys the other rows.
  function startOrStop(id) {
    if (root.runningCheck === id) {
      Quickshell.execDetached([root.script, "stop"])
    } else {
      if (root.runningCheck === "") root.running = { check: id, scope: root.choice[id], since: Date.now() / 1000 }
      Quickshell.execDetached([root.script, "start", id, root.choice[id]])
    }
    root.close()
  }

  function openReport() {
    Quickshell.execDetached([root.script, "report"])
    root.close()
  }

  function moveCursor(dx, dy) {
    root.cursorActive = true
    if (dy !== 0) root.cursor = Math.max(0, Math.min(root.rows.length, root.cursor + dy))
    else if (dx !== 0 && root.cursor < root.rows.length) root.stepChoice(root.rows[root.cursor].id, dx)
  }

  function activateCursor() {
    if (!root.cursorActive) return
    if (root.cursor < root.rows.length) root.startOrStop(root.rows[root.cursor].id)
    else root.openReport()
  }

  function applyState(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { data = {} }
    root.nowS = Date.now() / 1000
    root.running = data && data.running ? data.running : null
    root.checks = data && data.checks ? data.checks : ({})
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    stateFile.reload()
    var next = Object.assign({}, root.choice)
    for (var k in root.checks) if (root.option(k, root.checks[k].scope)) next[k] = root.checks[k].scope
    root.choice = next
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
    interval: root.opened || root.runningCheck !== "" ? 2000 : 30000
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
    foreground: root.findings > 0 ? root.alertColor : (root.runningCheck !== "" ? root.foreground : root.idleColor)
    tooltipText: root.runningCheck !== "" ? "Sicherheits-Check läuft: " + root.title(root.runningCheck)
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
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
          meta: root.runningCheck !== ""
            ? "Läuft im Hintergrund: " + root.title(root.running.part ? String(root.running.part) : root.runningCheck)
            : (root.findings > 0 ? root.findings + " Fund(e) beim letzten Check"
              : (root.lastRun > 0 ? "Nichts gefunden" : "Noch nicht geprüft"))
          detail: root.lastRun > 0 ? "Zuletzt " + root.ago(root.lastRun, "vor") : ""
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

        PanelSeparator { foreground: root.foreground }

        Button {
          text: "Letzten Bericht öffnen"
          iconText: ""
          hasCursor: root.cursorActive && root.cursor === root.rows.length
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.openReport()
          onHovered: function(isHovered) {
            if (!isHovered) return
            root.cursorActive = true
            root.cursor = root.rows.length
          }
        }
      }
    }
  }

  // One check: title and last result (or "läuft"), what the chosen scope
  // covers, the scope chips, and a play button (stop while it runs).
  component CheckRow: CursorSurface {
    id: row
    property var check: null
    property int rowIndex: 0

    readonly property string checkId: check ? String(check.id) : ""
    readonly property bool runningHere: root.runningCheck === checkId
    readonly property bool found: root.checks[checkId] !== undefined && root.checks[checkId].findings > 0
    readonly property var chosen: root.option(checkId, root.choice[checkId])

    hasCursor: root.cursorActive && root.cursor === rowIndex
    foreground: root.foreground
    opacity: root.runningCheck !== "" && !runningHere ? 0.5 : 1
    implicitHeight: rowContent.implicitHeight + Style.spacing.lg * 2

    HoverHandler {
      onHoveredChanged: if (hovered) {
        root.cursorActive = true
        root.cursor = row.rowIndex
      }
    }

    Column {
      id: rowContent
      anchors.left: parent.left
      anchors.right: playButton.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.md
      spacing: Style.spacing.xs

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
          text: root.result(row.checkId)
          width: Math.min(implicitWidth, parent.width * 0.65)
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
        text: row.chosen ? String(row.chosen.what) : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      ButtonGroup {
        options: row.check ? row.check.options : []
        value: root.choice[row.checkId] || ""
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        focusable: false
        onChanged: function(v) { root.choose(row.checkId, v) }
      }
    }

    PanelActionButton {
      id: playButton
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.verticalCenter: parent.verticalCenter
      // nf-fa-stop / nf-fa-play
      iconText: row.runningHere ? "" : ""
      tooltipText: row.runningHere ? "Abbrechen" : "Im Hintergrund starten"
      foreground: row.runningHere ? root.alertColor : root.foreground
      fontFamily: root.fontFamily
      onClicked: root.startOrStop(row.checkId)
    }
  }
}
