import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Clone of the stock omarchy.workspaces widget as of Omarchy 4.5.0
// (/usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml): the same
// per-monitor workspace logic and layout mode, an own look (short lines
// instead of numbers, the layout as one outline glyph after the row, a click
// never cycles the layout). A clone gets no stock fixes: diff it against that
// file after an Omarchy update.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
  // block of ten per monitor: 1-10, 11-20, and so on (see
  // default/hypr/monitor-workspaces.lua). Each bar shows its own monitor's
  // block, and the one that monitor shows, whichever monitor has focus.
  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // The first eight of the monitor's own (stock: five), and any of the rest
  // that exist. After them come workspaces that are only visiting: those of a
  // monitor that is unplugged, which had no room to join this one's.
  readonly property int alwaysShown: 8

  function workspaceIds() {
    var base = root.block * root.slots
    var ids = []
    for (var n = 1; n <= root.alwaysShown; n++) ids.push(base + n)
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  // A wheel notch moves one entry along the row, and a touchpad adds up its
  // smaller deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    // Holds at either end rather than wrapping, so a touchpad swipe that runs
    // long stops on the last workspace.
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // The layout of the workspace this monitor shows: drawn after the row as a
  // square (tiles), a circle (scrolls) or a triangle (floats).
  property string activeMode: "dwindle"
  property bool modeStale: false

  // A layout only changes through the layout commands, which ask for a refresh,
  // or a config reload, so each workspace's mode is read once and cached rather
  // than running the script on every workspace switch.
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0

  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId()]
    if (mode !== undefined) root.activeMode = mode
    else readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.activeWorkspaceId()
    if (id === -1) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }

  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    readMode()
  }

  Component.onCompleted: refresh()
  onMonitorChanged: root.showActiveMode()

  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        // A read that started before a refresh may predate the change.
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId()) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      // Deferred: the process still reports running while it signals exit.
      Qt.callLater(root.showActiveMode)
    }
  }

  // The layout commands (SUPER+H) change the mode without a focus change, so
  // they ask every bar to read it again.
  ShellIpc {
    target: "omarchy.workspaces"

    function refresh(): void { root.broadcast("refresh") }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property color ink: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color accent: root.bar ? root.bar.urgent : Color.urgent

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    // The workspaces, then the divider and the layout glyph.
    columns: root.vertical ? 1 : root.workspaceIds().length + 2
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: ws
        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property int slot: root.slotOf(modelData)
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block

        // A gap sets visiting workspaces apart from the monitor's own.
        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        bar: root.bar
        // A short line per workspace ("E" of the 2026-11-05 variants; dots and
        // a filled layout glyph before, which read as too heavy): the one this
        // bar's monitor shows = long and in the bar's urgent colour
        // (`bar.urgent`, the theme's `urgent` or the shell default), occupied
        // = the bar's text colour, empty = the same, faint.
        // `text` stays set even though the built-in label is hidden -
        // WidgetButton renders itself at opacity 0 when text is empty.
        text: slot === root.slots ? "0" : String(slot)
        labelVisible: false
        horizontalMargin: 5
        verticalPadding: 3
        fixedWidth: root.vertical ? root.barSize : Style.space(18)
        fixedHeight: root.barSize
        // The shown one on the focused monitor is already there; on another
        // monitor's bar a click moves the focus over.
        onPressed: function() {
          if (!(ws.shown && root.monitor !== null && root.monitor.focused)) root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        Rectangle {
          readonly property real length: Style.spaceReal(ws.shown ? 15 : 9)
          readonly property real weight: Style.spaceReal(ws.shown ? 2.5 : 1.5)

          anchors.centerIn: parent
          width: root.vertical ? weight : length
          height: root.vertical ? length : weight
          radius: weight / 2
          color: ws.shown ? root.accent : (ws.occupied ? root.ink : Util.alpha(root.ink, 0.28))

          Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
          Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
    }

    // A hairline between the workspaces and the layout glyph.
    Item {
      Layout.preferredWidth: root.vertical ? root.barSize : Style.space(9)
      Layout.preferredHeight: root.vertical ? Style.space(9) : root.barSize

      Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? Style.space(8) : Math.max(1, Style.spaceReal(0.8))
        height: root.vertical ? Math.max(1, Style.spaceReal(0.8)) : Style.space(8)
        color: Util.alpha(root.ink, 0.45)
      }
    }

    // The layout of the workspace this monitor shows, as a thin outline:
    // a square tiles, a circle scrolls, a triangle floats.
    Item {
      id: layoutGlyph

      readonly property real size: Style.spaceReal(8)
      readonly property real stroke: Style.spaceReal(1.25)

      Layout.preferredWidth: root.vertical ? root.barSize : Style.space(16)
      Layout.preferredHeight: root.vertical ? Style.space(16) : root.barSize

      Rectangle {
        anchors.centerIn: parent
        visible: root.activeMode !== "floating"
        width: layoutGlyph.size
        height: layoutGlyph.size
        radius: root.activeMode === "scrolling" ? width / 2 : Style.spaceReal(1.5)
        color: "transparent"
        border.width: layoutGlyph.stroke
        border.color: root.ink
      }

      Shape {
        id: triangle

        // The path runs half a stroke inside the box, so no edge is clipped.
        readonly property real inset: layoutGlyph.stroke / 2

        anchors.centerIn: parent
        visible: root.activeMode === "floating"
        width: Style.spaceReal(9)
        height: layoutGlyph.size
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeColor: root.ink
          strokeWidth: layoutGlyph.stroke
          fillColor: "transparent"
          joinStyle: ShapePath.RoundJoin
          startX: triangle.width / 2
          startY: triangle.inset

          PathLine { x: triangle.width - triangle.inset; y: triangle.height - triangle.inset }
          PathLine { x: triangle.inset; y: triangle.height - triangle.inset }
          PathLine { x: triangle.width / 2; y: triangle.inset }
        }
      }
    }
  }
}
