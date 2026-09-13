import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// A terminal glyph that turns red with a count badge while Claude Code
// sessions wait for a permission ("A" of the 2026-09-13 bar mockups). The
// count comes from `claude-notify count`: herdr agents in "blocked", plus the
// last plain terminal that asked and was not visited since. A click runs
// `claude-notify jump`, the same as SUPER+P.
BarWidget {
  id: root
  moduleName: "gradiscp.claude-status"

  property int waiting: 0

  readonly property string notify: Quickshell.env("HOME") + "/.local/bin/claude-notify"
  readonly property color alertColor: root.bar ? root.bar.urgent : Color.urgent
  readonly property color idleColor: Util.alpha(root.bar ? root.bar.barForeground : Color.foreground, 0.45)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: countProc
    command: [root.notify, "count"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(String(text).trim(), 10)
        root.waiting = isFinite(n) && n > 0 ? n : 0
      }
    }
  }

  // herdr offers no push event for agent state, so poll. Two seconds keeps the
  // badge in step with the permission toast without being noticeable.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!countProc.running) countProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    foreground: root.waiting > 0 ? root.alertColor : root.idleColor
    tooltipText: root.waiting === 0 ? "Keine Claude-Session wartet"
      : (root.waiting === 1 ? "1 Claude-Session wartet" : root.waiting + " Claude-Sessions warten")
    onPressed: if (root.waiting > 0) Quickshell.execDetached([root.notify, "jump"])

    Rectangle {
      visible: root.waiting > 0
      z: 10
      anchors { top: parent.top; right: parent.right; topMargin: Style.space(3); rightMargin: Style.space(2) }
      height: Style.space(10)
      width: Math.max(height, badgeText.implicitWidth + Style.space(5))
      radius: height / 2
      color: root.alertColor

      Text {
        id: badgeText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.waiting > 9 ? "9+" : String(root.waiting)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.space(8)
        font.bold: true
      }
    }
  }
}
