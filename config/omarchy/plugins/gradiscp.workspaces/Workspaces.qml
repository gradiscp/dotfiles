import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: ws
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property color ink: root.bar ? root.bar.barForeground : Color.foreground
        readonly property color accent: root.bar ? root.bar.urgent : Color.urgent

        bar: root.bar
        // A dot per workspace ("C" of the 2026-09-13 mockups): focused = red
        // capsule, occupied = filled dot, empty = hollow ring. Numbers were
        // tried underneath on 2026-09-16 and dropped again.
        // `text` stays set even though the built-in label is hidden -
        // WidgetButton renders itself at opacity 0 when text is empty.
        text: modelData === 10 ? "0" : String(modelData)
        labelVisible: false
        horizontalMargin: 5
        verticalPadding: 3
        fixedWidth: root.vertical ? root.barSize : Style.space(18)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        Rectangle {
          anchors.centerIn: parent
          width: ws.focused ? Style.space(14) : Style.space(7)
          height: Style.space(7)
          radius: height / 2
          color: ws.focused ? ws.accent : (ws.occupied ? ws.ink : "transparent")
          border.width: ws.focused || ws.occupied ? 0 : Math.max(1, Style.space(1))
          border.color: Util.alpha(ws.ink, 0.45)

          Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
