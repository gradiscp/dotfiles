import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Twingate client in the tray drawer: connection state, connect and
// disconnect, and the resources this account can reach.
//
// State comes from `twingate status` (no root), only while the system unit
// twingate.service runs (every 3 s while the panel is open, every 20 s
// otherwise); the resource list from `twingate resources`, read on opening
// and whenever the state changes to online. Connect and disconnect are
// `pkexec systemctl start|stop twingate` (fingerprint or password each time),
// the same commands `twingate start|stop` runs through sudo, which needs a
// terminal. Clicking a resource copies its alias, or else its address.
//
// No Twingate logo: Simple Icons has none, so the icon is nf-md-vpn. Hidden
// where the client is not installed.
Panel {
  id: root
  moduleName: "gradiscp.twingate"
  // Panel's own IpcHandler: `omarchy-shell gradiscp.twingate toggle`.
  ipcTarget: "gradiscp.twingate"
  visible: conn !== "missing"

  // missing | stopped | online | authenticating | offline | disconnected |
  // error | setup (never set up) | "" (not read yet, or unknown output)
  property string conn: ""
  property string rawStatus: ""
  property var resources: []
  property bool resourcesRead: false
  property string busy: ""
  property string message: ""
  property bool messageIsError: false

  readonly property bool serviceUp: conn !== "missing" && conn !== "stopped" && conn !== ""
  readonly property bool alert: conn === "authenticating" || conn === "error"
  readonly property color alertColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Commons.Color.foreground, 0.45)
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // nf-md-vpn (U+F0582) as its UTF-16 pair, so an edit cannot drop the glyph.
  readonly property string glyph: "󰖂"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function stateLabel() {
    switch (root.conn) {
    case "online": return "Connected"
    case "authenticating": return "Waiting for sign-in"
    case "offline": return "Offline"
    case "disconnected": return "Disconnected"
    case "error": return "Error"
    case "stopped": return "Off"
    case "setup": return "Not set up"
    case "missing": return "Not installed"
    case "": return root.rawStatus !== "" ? root.rawStatus : "Checking…"
    }
    return root.conn
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function readResources() {
    if (!resourcesProc.running) resourcesProc.running = true
  }

  function applyStatus(text) {
    var line = String(text).replace(/\x1b\[[0-9;]*m/g, "").trim().split("\n")[0] || ""
    var known = ["missing", "stopped", "online", "authenticating", "offline", "disconnected", "error"]
    var next = ""
    if (known.indexOf(line) >= 0) next = line
    else if (line.indexOf("twingate setup") >= 0) next = "setup"
    root.rawStatus = next === "" ? line : ""
    var wasOnline = root.conn === "online"
    root.conn = next
    if (next === "online" && (!wasOnline || root.opened)) root.readResources()
    if (next !== "online") { root.resources = []; root.resourcesRead = false }
  }

  // `twingate resources` prints a tab-separated table: name, address, alias,
  // auth status (padded with spaces), under one header line.
  function applyResources(text) {
    var rows = []
    String(text).replace(/\x1b\[[0-9;]*m/g, "").split("\n").forEach(function(l) {
      var f = l.split("\t").map(function(s) { return s.trim() })
      if (f.length < 2 || f[0] === "" || f[0] === "RESOURCE NAME") return
      rows.push({
        name: f[0],
        address: f[1],
        alias: f.length > 2 && f[2] !== "-" ? f[2] : "",
        auth: f.length > 3 ? f[3] : ""
      })
    })
    root.resources = rows
    root.resourcesRead = true
  }

  function setService(start) {
    if (root.busy !== "") return
    root.busy = start ? "start" : "stop"
    root.message = "Confirm with your fingerprint or password…"
    root.messageIsError = false
    serviceProc.command = ["pkexec", "systemctl", start ? "start" : "stop", "twingate"]
    serviceProc.running = true
  }

  // pkexec: 126 = the prompt was dismissed, 127 = not authorised.
  function serviceFinished(code) {
    var what = root.busy
    root.busy = ""
    root.messageIsError = false
    if (code === 0) {
      root.message = what === "start" ? "Started. Signing in can take a few seconds." : "Stopped."
    } else if (code === 126 || code === 127) {
      root.message = "Cancelled, nothing changed."
    } else {
      var err = String(serviceErr.text).trim().split("\n").filter(function(l) { return l !== "" })
      root.message = err.length > 0 ? err[err.length - 1] : "systemctl failed (exit " + code + ")"
      root.messageIsError = true
    }
    root.refresh()
  }

  function copyAddress(res) {
    var text = res.alias !== "" ? res.alias : res.address
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
    root.message = "Copied " + text
    root.messageIsError = false
  }

  onOpenedChanged: if (opened) {
    if (panelFlick) panelFlick.contentY = 0
    if (root.busy === "") root.message = ""
    root.refresh()
    if (root.conn === "online") root.readResources()
  }

  Process {
    id: statusProc
    command: ["bash", "-c",
      "command -v twingate >/dev/null || { echo missing; exit; }; "
      + "systemctl is-active --quiet twingate || { echo stopped; exit; }; "
      + "timeout 5 twingate status 2>&1 | head -n 1"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
  }

  Process {
    id: resourcesProc
    command: ["timeout", "10", "twingate", "resources"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyResources(text) }
  }

  Process {
    id: serviceProc
    property int exitCode: 0
    stderr: StdioCollector { id: serviceErr; waitForEnd: true }
    // The collector may finish just after the exit; read it a moment later.
    onExited: function(exitCode, exitStatus) {
      serviceProc.exitCode = exitCode
      serviceDone.restart()
    }
  }

  Timer {
    id: serviceDone
    interval: 150
    onTriggered: root.serviceFinished(serviceProc.exitCode)
  }

  Timer {
    interval: root.opened ? 3000 : 20000
    running: root.conn !== "missing"
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    foreground: root.alert ? root.alertColor : (root.conn === "online" ? root.foreground : root.idleColor)
    tooltipText: "Twingate: " + root.stateLabel()
    onPressed: function(button) { root.toggle() }
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
          title: "Twingate"
          meta: root.stateLabel()
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

        // ---- connection ---------------------------------------------------
        Section {
          title: "CONNECTION"

          Item {
            width: parent.width
            implicitHeight: Math.max(connNote.implicitHeight, powerButton.height)

            Note {
              id: connNote
              anchors.left: parent.left
              anchors.right: powerButton.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              alert: root.messageIsError || (root.message === "" && root.alert)
              text: root.message !== "" ? root.message
                : root.conn === "setup" ? "Run `twingate setup` in a terminal once: network name, then the sign-in in the browser."
                : root.conn === "authenticating" ? "Twingate is waiting for you to sign in."
                : root.serviceUp ? "Disconnecting stops the Twingate service; it asks for your fingerprint."
                : "Connecting starts the Twingate service; it asks for your fingerprint."
            }

            // nf-fa-power_off
            PanelActionButton {
              id: powerButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              tooltipText: root.serviceUp ? "Disconnect" : "Connect"
              foreground: root.serviceUp ? root.foreground : root.dim
              fontFamily: root.fontFamily
              opacity: root.busy === "" && root.conn !== "setup" ? 1 : 0.4
              onClicked: if (root.conn !== "setup") root.setService(!root.serviceUp)
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
          visible: root.conn === "online"
        }

        // ---- resources ----------------------------------------------------
        Section {
          title: "RESOURCES"
          visible: root.conn === "online"

          Repeater {
            model: root.resources

            ResourceRow {
              required property var modelData
              resource: modelData
            }
          }

          Note {
            text: !root.resourcesRead ? "Reading…"
              : root.resources.length === 0 ? "No resources for this account."
              : "Click one to copy its address."
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

  // Resource name on the left, alias or address (and a pending auth state)
  // on the right; a click copies the address.
  component ResourceRow: Item {
    id: row
    property var resource: ({})
    width: parent ? parent.width : 0
    implicitHeight: Math.max(nameText.implicitHeight, addressText.implicitHeight)

    Text {
      id: nameText
      anchors.left: parent.left
      width: Math.min(implicitWidth, parent.width * 0.5)
      textFormat: Text.PlainText
      text: String(row.resource.name || "")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: addressText
      anchors.right: parent.right
      width: Math.min(implicitWidth, parent.width - nameText.width - Style.spacing.xl)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: (row.resource.alias || row.resource.address || "")
        + (row.resource.auth ? " · " + row.resource.auth : "")
      color: mouse.containsMouse ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideLeft
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.copyAddress(row.resource)
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
