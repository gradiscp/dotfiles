import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Framework laptop at a glance (meant for the tray drawer): battery and
// charger, the EC's battery care, the laptop panel's refresh rate, EC
// temperatures and fan, expansion cards and firmware.
//
// Everything shown comes from `framework-panel status` (bin/, no root): every
// 2 s while the panel is open, every 30 s otherwise (for the icon), plus
// fwupd's update list once per opening. The battery-care chips go through
// `pkexec /usr/local/bin/framework-ec set ...` (root: fingerprint or password
// each time), which also keeps the values in /etc/framework-ec.conf for
// framework-ec.service to apply at boot and after resume. The chips show that
// file; "Read from EC" asks the EC itself. The refresh rate needs no root:
// `framework-panel refresh-rate`, read by config/hypr/monitors.lua.
//
// The icon turns to the bar's urgent colour when the charger offers less than
// 45 W (too little to run the laptop and charge at 0.3C; the stock battery
// icon then shows "Threshold") or an EC sensor reaches the EC's own warning
// level.
Panel {
  id: root
  moduleName: "gradiscp.framework"
  // Panel's own IpcHandler: `omarchy-shell gradiscp.framework toggle`.
  ipcTarget: "gradiscp.framework"

  property var info: null
  property var fwupd: null
  // The battery-care setting a pkexec call is changing ("status" while
  // reading), and the value it asked for.
  property string busy: ""
  property string pending: ""
  property string message: ""
  property bool messageIsError: false
  property string ecReport: ""
  property string pendingRate: ""
  property bool fwChecking: false
  readonly property bool hasUpdates: fwupd !== null && fwupd.updates instanceof Array && fwupd.updates.length > 0

  readonly property string panelScript: Quickshell.env("HOME") + "/.local/bin/framework-panel"
  readonly property string ecHelper: "/usr/local/bin/framework-ec"
  readonly property int weakChargerW: 45

  readonly property var battery: info && info.battery ? info.battery : null
  readonly property var charger: info && info.charger ? info.charger : null
  readonly property var ec: info && info.ec ? info.ec : null
  readonly property var lcd: info && info.display ? info.display : null
  readonly property var firmware: info && info.firmware ? info.firmware : null
  readonly property var temps: info && info.temps instanceof Array ? info.temps : []
  readonly property var cards: info && info.cards instanceof Array ? info.cards : []
  readonly property bool helperReady: ec !== null && ec.helper === true

  readonly property bool weakCharger: charger !== null && charger.online === true
    && typeof charger.max_w === "number" && charger.max_w < weakChargerW
  readonly property bool hot: {
    for (var i = 0; i < temps.length; i++) {
      var t = temps[i]
      if (typeof t.c === "number" && typeof t.max === "number" && t.c >= t.max) return true
    }
    return false
  }
  readonly property bool alert: weakCharger || hot

  readonly property var limitOptions: [
    { value: "60", label: "60%" }, { value: "65", label: "65%" }, { value: "70", label: "70%" },
    { value: "80", label: "80%" }, { value: "100", label: "100%" }
  ]
  readonly property var rateOptions: [
    { value: "0.3", label: "0.3C gentle" }, { value: "0.5", label: "0.5C" }, { value: "1", label: "Full speed" }
  ]
  readonly property var ledOptions: [
    { value: "1", label: "1%" }, { value: "25", label: "25%" }, { value: "50", label: "50%" }, { value: "100", label: "100%" }
  ]
  readonly property var rateChoices: [
    { value: "auto", label: "Auto" }, { value: "60", label: "60 Hz" }, { value: "120", label: "120 Hz" }
  ]

  readonly property color alertColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Commons.Color.foreground, 0.45)
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyInfo(text) {
    try { root.info = JSON.parse(text) } catch (e) { root.info = null }
    if (root.lcd && root.pendingRate === root.lcd.choice) root.pendingRate = ""
  }

  function applyFwupd(text) {
    var data = null
    try { data = JSON.parse(text) } catch (e) {}
    root.fwupd = data && data.fwupd ? data.fwupd : { updates: [], checked: null, failed: true }
  }

  // The EC value a chip row shows: the one being set, else the saved one.
  function ecValue(setting, saved) {
    if (root.busy === setting) return root.pending
    if (saved === null || saved === undefined) return ""
    var s = String(saved)
    return s === "1.0" ? "1" : s
  }

  function setEc(setting, value) {
    if (root.busy !== "" || !root.helperReady) return
    root.busy = setting
    root.pending = value
    root.message = "Confirm with your fingerprint or password…"
    root.messageIsError = false
    ecProc.command = ["pkexec", root.ecHelper, "set", setting, value]
    ecProc.running = true
  }

  function readEc() {
    if (root.busy !== "" || !root.helperReady) return
    root.busy = "status"
    root.message = "Confirm with your fingerprint or password…"
    root.messageIsError = false
    ecProc.command = ["pkexec", root.ecHelper, "status"]
    ecProc.running = true
  }

  // pkexec: 126 = the prompt was dismissed, 127 = not authorised.
  function ecFinished(code) {
    var what = root.busy
    root.busy = ""
    root.pending = ""
    root.messageIsError = false
    if (code === 0 && what === "status") {
      var values = {}
      String(ecOut.text).split("\n").forEach(function(l) {
        var m = /^([a-z_]+)=([0-9]+)$/.exec(l)
        if (m) values[m[1]] = m[2]
      })
      root.ecReport = "EC now: charge limit " + (values.charge_limit || "?") + "%, LED "
        + (values.fp_brightness || "?") + "% (" + Qt.formatTime(new Date(), "HH:mm") + ")"
      root.message = ""
    } else if (code === 0) {
      root.message = "Saved. Applied again at boot and after resume."
    } else if (code === 126 || code === 127) {
      root.message = "Cancelled, nothing changed."
    } else {
      var err = String(ecErr.text).trim().split("\n").filter(function(l) { return l !== "" })
      root.message = err.length > 0 ? err[err.length - 1] : "framework-ec failed (exit " + code + ")"
      root.messageIsError = true
    }
    root.refresh()
  }

  function setRate(value) {
    root.pendingRate = value
    rateProc.command = [root.panelScript, "refresh-rate", value]
    rateProc.running = true
  }

  function updateFirmware() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update-firmware"])
    root.close()
  }

  function batteryText() {
    var b = root.battery
    if (!b) return "No battery"
    var p = (typeof b.percent === "number" ? b.percent : "?") + "%"
    var w = typeof b.watts === "number" ? b.watts + " W" : ""
    var s = String(b.status)
    if (s === "Charging") return p + " · charging" + (w ? ", " + w : "")
    if (s === "Discharging") return p + " · on battery" + (w ? ", " + w : "")
    if (s === "Full") return p + " · full"
    if (s === "Not charging") return p + " · holding at the charge limit"
    return p + " · " + s.toLowerCase()
  }

  function chargerText() {
    var c = root.charger
    if (!c || c.online !== true) return "Not plugged in"
    if (typeof c.max_w !== "number") return "Plugged in"
    var volts = (c.offers || []).map(function(o) { return o.volts + " V" }).join(", ")
    return c.max_w + " W max" + (volts ? " (" + volts + ")" : "")
      + (typeof c.now_w === "number" ? " · " + c.now_w + " W now" : "")
  }

  function healthText() {
    var b = root.battery
    if (!b) return "—"
    return (typeof b.health === "number" ? b.health + "% of new" : "—")
      + (typeof b.cycles === "number" ? " · " + b.cycles + (b.cycles === 1 ? " cycle" : " cycles") : "")
  }

  function screenText() {
    var d = root.lcd
    if (!d) return "—"
    if (!d.on) return "Off"
    return (typeof d.hz === "number" ? d.hz + " Hz" : "?") + (d.profile ? " · " + d.profile + " profile" : "")
  }

  function updatesText() {
    var f = root.fwupd
    if (root.fwChecking) return "Checking LVFS…"
    if (!f) return "…"
    if (f.failed) return "fwupd did not answer"
    if (root.hasUpdates) return f.updates.length + " available"
    if (f.checked === null || f.checked === undefined) return "Never checked"
    return "Up to date · checked " + Qt.formatDate(new Date(Number(f.checked) * 1000), "d MMM yyyy")
  }

  // Downloads fwupd's list from LVFS (no root, nothing installed), then
  // reads the result again.
  function checkFirmware() {
    if (root.fwChecking) return
    root.fwChecking = true
    fwRefreshProc.running = true
  }

  onOpenedChanged: if (opened) {
    if (panelFlick) panelFlick.contentY = 0
    root.message = root.busy !== "" ? root.message : ""
    root.refresh()
    root.fwupd = null
    if (!fwProc.running) fwProc.running = true
  }

  Process {
    id: statusProc
    command: [root.panelScript, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyInfo(text) }
  }

  Process {
    id: fwProc
    command: [root.panelScript, "status", "--firmware"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyFwupd(text) }
  }

  Process {
    id: ecProc
    property int exitCode: 0
    stdout: StdioCollector { id: ecOut; waitForEnd: true }
    stderr: StdioCollector { id: ecErr; waitForEnd: true }
    // The collectors may finish just after the exit; read them a moment later.
    onExited: function(exitCode, exitStatus) {
      ecProc.exitCode = exitCode
      ecDone.restart()
    }
  }

  Timer {
    id: ecDone
    interval: 150
    onTriggered: root.ecFinished(ecProc.exitCode)
  }

  Process {
    id: rateProc
    onExited: root.refresh()
  }

  Process {
    id: fwRefreshProc
    command: ["fwupdmgr", "refresh", "--force"]
    onExited: {
      root.fwChecking = false
      root.fwupd = null
      fwProc.running = true
    }
  }

  Timer {
    interval: root.opened ? 2000 : 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // The Framework gear (FrameworkIcon.qml), centred in the icon slot.
    iconComponent: Component {
      Item {
        FrameworkIcon {
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          iconSize: button.iconSize
          color: root.alert ? root.alertColor : root.idleColor
        }
      }
    }
    foreground: root.alert ? root.alertColor : root.idleColor
    tooltipText: root.weakCharger ? "Framework: charger too weak (" + root.charger.max_w + " W)"
      : (root.hot ? "Framework: running hot" : "Framework")
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(1100))

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
          title: "Framework"
          meta: root.firmware && root.firmware.product ? String(root.firmware.product) : ""
          detail: root.weakCharger ? "Weak charger" : (root.hot ? "Running hot" : "")
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            FrameworkIcon {
              iconSize: Style.font.display
              color: root.alert ? root.alertColor : root.foreground
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- power ----------------------------------------------------------
        Section {
          title: "POWER"

          InfoPair { label: "Battery"; value: root.batteryText() }
          InfoPair { label: "Charger"; value: root.chargerText(); alert: root.weakCharger }
          InfoPair { label: "Battery health"; value: root.healthText() }

          Note {
            visible: root.weakCharger
            alert: true
            text: root.weakCharger
              ? "This charger offers only " + root.charger.max_w + " W. The laptop uses most of it, so the battery "
                + "barely charges, and the battery icon shows Threshold. Use a USB-C PD charger with 60 W or more."
              : ""
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- battery care (EC, root) ----------------------------------------
        Section {
          title: "BATTERY CARE"

          Note {
            visible: !root.helperReady
            text: "framework-ec is not installed: run install.sh to set these from here."
          }

          ChipRow {
            label: "Charge limit"
            options: root.limitOptions
            value: root.ecValue("charge-limit", root.ec ? root.ec.charge_limit : null)
            onPicked: function(v) { root.setEc("charge-limit", v) }
          }

          ChipRow {
            label: "Charge speed"
            options: root.rateOptions
            value: root.ecValue("charge-rate", root.ec ? root.ec.charge_rate : null)
            onPicked: function(v) { root.setEc("charge-rate", v) }
          }

          ChipRow {
            label: "Fingerprint LED"
            options: root.ledOptions
            value: root.ecValue("fp-brightness", root.ec ? root.ec.fp_brightness : null)
            onPicked: function(v) { root.setEc("fp-brightness", v) }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(ecNote.implicitHeight, readButton.height)
            visible: root.helperReady

            Note {
              id: ecNote
              anchors.left: parent.left
              anchors.right: readButton.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              alert: root.messageIsError
              text: root.message !== "" ? root.message
                : (root.ecReport !== "" ? root.ecReport
                  : "Each change asks for your fingerprint. Saved values are applied again at boot and after resume.")
            }

            // nf-fa-refresh: read the values back from the EC itself.
            PanelActionButton {
              id: readButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf021"
              tooltipText: "Read from EC"
              foreground: root.foreground
              fontFamily: root.fontFamily
              opacity: root.busy === "" ? 1 : 0.4
              onClicked: root.readEc()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- display --------------------------------------------------------
        Section {
          title: "DISPLAY"

          InfoPair { label: "Laptop panel"; value: root.screenText() }

          ChipRow {
            label: ""
            enabled: true
            options: root.rateChoices
            value: root.pendingRate !== "" ? root.pendingRate : (root.lcd ? String(root.lcd.choice) : "")
            onPicked: function(v) { root.setRate(v) }
          }

          Note { text: "Auto: 120 Hz only in the Performance power profile, else 60 Hz." }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- temperatures ---------------------------------------------------
        Section {
          title: "TEMPERATURES"

          Repeater {
            model: root.temps

            InfoPair {
              required property var modelData
              label: String(modelData.name)
              value: typeof modelData.c === "number" ? modelData.c + " °C" : "—"
              alert: typeof modelData.c === "number" && typeof modelData.max === "number" && modelData.c >= modelData.max
            }
          }

          InfoPair {
            label: "Fan"
            value: root.info && typeof root.info.fan_rpm === "number" ? (root.info.fan_rpm > 0 ? root.info.fan_rpm + " rpm" : "Off") : "—"
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- expansion cards ------------------------------------------------
        Section {
          title: "EXPANSION CARDS"

          Repeater {
            model: root.cards

            Text {
              required property var modelData
              width: parent.width
              textFormat: Text.PlainText
              text: String(modelData.name)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          Note {
            text: (root.cards.length === 0 ? "None that report themselves. " : "")
              + "USB-C and USB-A cards are passive and do not show up."
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- firmware -------------------------------------------------------
        Section {
          title: "FIRMWARE"

          InfoPair { label: "BIOS"; value: root.firmware && root.firmware.bios ? String(root.firmware.bios) : "—" }
          InfoPair { label: "EC"; value: root.firmware && root.firmware.ec ? String(root.firmware.ec) : "—" }
          InfoPair {
            label: "Updates"
            value: root.updatesText()
            alert: root.hasUpdates
          }

          Repeater {
            model: root.hasUpdates ? root.fwupd.updates : []

            InfoPair {
              required property var modelData
              label: String(modelData.name)
              value: String(modelData.version) + " → " + String(modelData.update)
            }
          }

          // Without updates the button checks LVFS again; with some it
          // installs them in a terminal. Only then does it show a download.
          Item {
            width: parent.width
            implicitHeight: Math.max(fwNote.implicitHeight, fwButton.height)

            Note {
              id: fwNote
              anchors.left: parent.left
              anchors.right: fwButton.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              text: root.hasUpdates
                ? "Installs in a terminal (omarchy update firmware); a BIOS update finishes with a reboot."
                : "Check asks LVFS for new firmware; nothing is installed."
            }

            PanelActionButton {
              id: fwButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              // nf-fa-download / nf-fa-refresh
              iconText: root.hasUpdates ? "\uf019" : "\uf021"
              tooltipText: root.hasUpdates ? "Install updates" : "Check for updates"
              foreground: root.hasUpdates ? root.alertColor : root.foreground
              fontFamily: root.fontFamily
              opacity: root.fwChecking ? 0.4 : 1
              onClicked: root.hasUpdates ? root.updateFirmware() : root.checkFirmware()
            }
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

  // Label on the left, value on the right (as in the stock power panel).
  component InfoPair: Item {
    property string label: ""
    property string value: ""
    property bool alert: false
    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: parent.label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      id: valueText
      anchors.right: parent.right
      width: Math.min(implicitWidth, parent.width - labelText.implicitWidth - Style.spacing.xl)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: parent.value
      color: parent.alert ? root.alertColor : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideLeft
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

  // A label above one row of chips; greyed and inert while a pkexec call runs
  // or framework-ec is missing.
  component ChipRow: Column {
    id: chipRow
    property string label: ""
    property var options: []
    property string value: ""
    signal picked(string value)
    width: parent ? parent.width : 0
    spacing: Style.spacing.xs
    enabled: root.helperReady && root.busy === ""
    opacity: enabled ? 1 : 0.5

    Text {
      visible: chipRow.label !== ""
      textFormat: Text.PlainText
      text: chipRow.label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    ButtonGroup {
      options: chipRow.options
      value: chipRow.value
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      focusable: false
      onChanged: function(v) { if (v !== chipRow.value) chipRow.picked(v) }
    }
  }
}
