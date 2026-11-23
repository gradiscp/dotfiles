import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One icon for "is there anything I have to take care of?". Dim while
// nothing is open, bright while a repo has uncommitted or unpushed work or a
// recurring chore is due (system update, .pacnew merges, firmware), and
// in the bar's urgent colour once unpushed commits are older than `staleHours`
// (bar entry setting, default 24): with pushes done by hand, that work exists
// on this laptop only. Urgent too while a homelab check fails (Gatus, shown
// only when ops-status has its address; "not reachable" is no alarm). The count is in the tooltip, like gradiscp.ai-status.
//
// Data comes from bin/ops-status (JSON, about 0.15 s for six repos, no
// network; which chores exist and when they are due is decided there), once a minute and every five seconds while the panel is open.
// Each monitor's widget polls for itself; at this rate that is cheaper than
// sharing state. "Unpushed" is measured against the last fetch.
//
// Clicks: a repo opens a terminal there (nothing is pushed), a chore starts
// in a floating terminal, a homelab check opens that device's page, or Gatus
// where ops-status knows no page for it (`ops-status run`).
// The panel opens on the focused monitor with
// `omarchy-shell shell toggle gradiscp.ops`.
Panel {
  id: root
  moduleName: "gradiscp.ops"
  ipcTarget: "gradiscp.ops"

  property var repos: []
  // Recurring chores, each {label, text, due}.
  property var due: []
  // null without a Gatus address, else {state: ok|offline|unreachable, checks}.
  property var homelab: null
  property double nowS: 0
  // "" not read yet, "ok", or "failed" (script missing or its output unreadable)
  property string health: ""

  readonly property int staleHours: Number(root.setting("staleHours", 24)) || 24
  readonly property string script: Quickshell.env("HOME") + "/.local/bin/ops-status"
  readonly property color alertColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Commons.Color.foreground, 0.45)
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // nf-oct-checklist, escaped so an edit cannot drop the glyph.
  readonly property string glyph: ""

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < repos.length; i++) if (root.isOpen(repos[i])) n++
    return n
  }
  readonly property int dueCount: {
    var n = 0
    for (var i = 0; i < due.length; i++) if (due[i].due === true) n++
    return n
  }
  readonly property int failing: {
    var n = 0
    var checks = homelab && homelab.checks instanceof Array ? homelab.checks : []
    for (var i = 0; i < checks.length; i++) if (checks[i].ok !== true) n++
    return n
  }
  readonly property bool alert: stale || failing > 0 || health === "failed"
  readonly property bool stale: {
    for (var i = 0; i < repos.length; i++) if (root.isStale(repos[i])) return true
    return false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // A branch whose upstream is gone is cleanup (git tidy), not open work.
  function isOpen(repo) {
    return repo.dirty > 0 || repo.unpushed > 0 || repo.noUpstream > 0
  }

  function isStale(repo) {
    return repo.oldestUnpushed > 0 && root.nowS - repo.oldestUnpushed > root.staleHours * 3600
  }

  function summary() {
    if (root.health === "failed") return "ops-status failed"
    if (root.health === "") return "Checking…"
    var parts = []
    if (root.failing > 0) parts.push(root.failing + (root.failing === 1 ? " check" : " checks") + " failing")
    if (root.openCount > 0) parts.push(root.openCount + (root.openCount === 1 ? " repo" : " repos") + " open")
    if (root.dueCount > 0) parts.push(root.dueCount + " due")
    return parts.length > 0 ? parts.join(" · ") : "Nothing open, nothing due"
  }

  function repoText(repo) {
    var parts = []
    if (repo.dirty > 0) parts.push(repo.dirty + " uncommitted")
    if (repo.unpushed > 0) parts.push(repo.unpushed + " unpushed" + (root.isStale(repo) ? " (" + root.age(repo.oldestUnpushed) + ")" : ""))
    if (repo.noUpstream > 0) parts.push(repo.noUpstream + " without upstream")
    if (repo.gone > 0) parts.push(repo.gone + " upstream gone")
    if (repo.stash > 0) parts.push(repo.stash + " stash")
    return parts.length > 0 ? parts.join(" · ") : "clean"
  }

  function age(epoch) {
    var hours = Math.floor((root.nowS - epoch) / 3600)
    return hours < 48 ? hours + " h" : Math.floor(hours / 24) + " d"
  }

  // Open work first, then by name, as the script sorted them.
  function sorted() {
    var open = [], clean = []
    for (var i = 0; i < repos.length; i++) (root.isOpen(repos[i]) ? open : clean).push(repos[i])
    return open.concat(clean)
  }

  function apply(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { data = null }
    // A failed poll keeps the last good list and only marks the state.
    if (!data || !(data.repos instanceof Array)) { root.health = "failed"; return }
    root.repos = data.repos
    root.due = data.due instanceof Array ? data.due : []
    root.homelab = data.homelab && typeof data.homelab === "object" ? data.homelab : null
    root.nowS = Number(data.now) || Date.now() / 1000
    root.health = "ok"
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function homelabText() {
    if (!root.homelab) return ""
    if (root.homelab.state === "offline") return "Twingate is offline, so the checks cannot be read."
    if (root.homelab.state !== "ok") return "Gatus is not reachable."
    var total = root.homelab.checks.length
    return (total - root.failing) + " of " + total + " checks pass. Click one to open the device."
  }

  function run(action, name) {
    if (!action) return
    var command = [root.script, "run", String(action)]
    if (name !== undefined) command.push(String(name))
    Quickshell.execDetached(command)
    root.close()
  }

  function openTerminal(repo) {
    Quickshell.execDetached(["xdg-terminal-exec", "--dir=" + String(repo.path)])
    root.close()
  }

  onOpenedChanged: if (opened) {
    if (panelFlick) panelFlick.contentY = 0
    root.refresh()
  }

  Process {
    id: statusProc
    command: [root.script]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
  }

  Timer {
    interval: root.opened ? 5000 : 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    foreground: root.alert ? root.alertColor
      : (root.openCount > 0 || root.dueCount > 0 ? root.foreground : root.idleColor)
    tooltipText: "Ops: " + root.summary()
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

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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

        PanelHero {
          width: parent.width
          title: "Ops"
          meta: root.summary()
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: root.glyph
              color: root.alert ? root.alertColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Section {
          title: "REPOS"

          Repeater {
            model: root.sorted()

            RepoRow {
              required property var modelData
              repo: modelData
            }
          }

          Note {
            alert: root.health === "failed"
            text: root.health === "failed" ? "Could not read `ops-status`; the list above is the last good one."
              : root.repos.length === 0 ? "No git repos found."
              : "Unpushed is measured against the last fetch. Click a repo to open a terminal there."
          }
        }

        PanelSeparator {
          foreground: root.foreground
          visible: root.due.length > 0
        }

        Section {
          title: "DUE"
          visible: root.due.length > 0

          Repeater {
            model: root.due

            DueRow {
              required property var modelData
              entry: modelData
            }
          }

          Note { text: "Click one to run it in a terminal." }
        }

        PanelSeparator {
          foreground: root.foreground
          visible: root.homelab !== null
        }

        Section {
          title: "HOMELAB"
          visible: root.homelab !== null

          Repeater {
            model: root.homelab && root.homelab.checks instanceof Array ? root.homelab.checks : []

            CheckRow {
              required property var modelData
              check: modelData
            }
          }

          Note {
            alert: root.failing > 0
            text: root.homelabText()
          }
        }
      }
      }
    }
  }

  // A titled block of rows.
  component Section: Column {
    property string title: ""
    width: parent ? parent.width : 0
    spacing: Style.spacing.sm

    PanelSectionHeader {
      width: parent.width
      text: parent.title
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // Repo name on the left, its open work on the right; a click opens a
  // terminal in the repo.
  component RepoRow: Item {
    id: row
    property var repo: ({})
    readonly property bool open: root.isOpen(repo)
    width: parent ? parent.width : 0
    implicitHeight: Math.max(nameText.implicitHeight, workText.implicitHeight)

    Text {
      id: nameText
      anchors.left: parent.left
      width: Math.min(implicitWidth, parent.width * 0.45)
      textFormat: Text.PlainText
      text: String(row.repo.name || "")
      color: row.open || mouse.containsMouse ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: workText
      anchors.right: parent.right
      width: Math.min(implicitWidth, parent.width - nameText.width - Style.spacing.xl)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: root.repoText(row.repo)
      color: root.isStale(row.repo) ? root.alertColor : (row.open ? root.foreground : root.dim)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideLeft
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openTerminal(row.repo)
    }
  }

  // A chore on the left, its state on the right; bright while it is due.
  component DueRow: Item {
    id: dueRow
    property var entry: ({})
    readonly property bool isDue: entry.due === true
    width: parent ? parent.width : 0
    implicitHeight: Math.max(dueLabel.implicitHeight, dueText.implicitHeight)

    Text {
      id: dueLabel
      anchors.left: parent.left
      width: Math.min(implicitWidth, parent.width * 0.45)
      textFormat: Text.PlainText
      text: String(dueRow.entry.label || "")
      color: dueRow.isDue || dueMouse.containsMouse ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: dueText
      anchors.right: parent.right
      width: Math.min(implicitWidth, parent.width - dueLabel.width - Style.spacing.xl)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: String(dueRow.entry.text || "")
      color: dueRow.isDue ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideLeft
    }

    MouseArea {
      id: dueMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.run(dueRow.entry.action)
    }
  }

  // A homelab check on the left, its last result on the right; a click opens
  // the device's page in the browser.
  component CheckRow: Item {
    id: checkRow
    property var check: ({})
    readonly property bool ok: check.ok === true
    width: parent ? parent.width : 0
    implicitHeight: Math.max(checkName.implicitHeight, checkState.implicitHeight)

    Text {
      id: checkName
      anchors.left: parent.left
      width: Math.min(implicitWidth, parent.width * 0.7)
      textFormat: Text.PlainText
      text: String(checkRow.check.name || "")
      color: !checkRow.ok ? root.alertColor : (checkMouse.containsMouse ? root.foreground : root.dim)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: checkState
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: checkRow.ok ? "ok" : "failing"
      color: checkRow.ok ? root.dim : root.alertColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: checkMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.run("check", checkRow.check.name)
    }
  }

  // A small wrapped caption.
  component Note: Text {
    property bool alert: false
    width: parent ? parent.width : 0
    textFormat: Text.PlainText
    color: alert ? root.alertColor : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
