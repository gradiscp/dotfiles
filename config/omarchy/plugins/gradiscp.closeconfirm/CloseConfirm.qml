import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// SUPER+W's "close anyway?" question, summoned by bin/window-close-guard when
// the terminal about to close still has something running in it:
//   omarchy-shell shell summon gradiscp.closeconfirm '{"process":"claude"}'
// A slim strip under the bar ("C" of three mockups, picked 2026-09-16 over the
// centred terminal card): no dimmed backdrop, translucent like the
// notification toasts - Color.notifications.background carries the theme's
// 0.85 alpha, and hyprland.lua blurs the "gradiscp-closeconfirm" layer.
// Keys: Tab / Shift+Tab / Left / Right switch, Enter picks, Escape cancels,
// SUPER+W again confirms. The answer goes back to window-close-guard, which
// knows which window it was.
Item {
  id: root

  // Injected by omarchy-shell.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string process: ""
  // 0 = Abbrechen, 1 = Schließen.
  property int selected: 0

  readonly property string guard: Quickshell.env("HOME") + "/.local/bin/window-close-guard"
  readonly property string fontFamily: Style.font.menuFamily
  readonly property color ink: Color.notifications.text
  readonly property color brightInk: Qt.lighter(Color.notifications.text, 1.15)
  readonly property color accent: Color.notifications.border
  readonly property color cardColor: Color.notifications.background
  readonly property int borderWidth: 2

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.process = payload.process || ""
    // Start on "Abbrechen", so a stray Enter keeps the window.
    root.selected = 0
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function answer(verb) {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "gradiscp.closeconfirm")
    Quickshell.execDetached([root.guard, verb])
  }

  PanelWindow {
    id: panel
    visible: root.opened
    // Full screen, but painted transparent: the whole surface is only there to
    // take the keyboard focus and to catch a click beside the strip.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "gradiscp-closeconfirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: root.answer("cancel")
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.answer("cancel")
        } else if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) {
          // SUPER+W again = yes. window-close-guard handles this when
          // Hyprland's bind sees the key; this covers the key reaching the
          // dialog instead, while it holds exclusive keyboard focus.
          root.answer("confirm")
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab
                   || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
          root.selected = root.selected === 0 ? 1 : 0
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.answer(root.selected === 1 ? "confirm" : "cancel")
        } else {
          return
        }
        event.accepted = true
      }
    }

    Rectangle {
      id: strip
      // Clear of the bar: its height plus the usual outer gap.
      anchors { top: parent.top; topMargin: Style.bar.sizeHorizontal + Style.space(6); horizontalCenter: parent.horizontalCenter }
      width: content.implicitWidth + Style.space(28)
      height: Style.space(44)
      radius: Style.cornerRadius
      color: root.cardColor
      border.color: root.accent
      border.width: root.borderWidth

      // Swallow clicks on the strip so only the area beside it cancels.
      MouseArea { anchors.fill: parent; onClicked: {} }

      Row {
        id: content
        anchors.centerIn: parent
        spacing: Style.space(12)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: ""
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
        }

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText
            text: root.process || "etwas"
            color: root.brightInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: "läuft noch. Schließen?"
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Repeater {
            model: ["Abbrechen", "Schließen"]

            Rectangle {
              required property int index
              required property string modelData

              readonly property bool isSelected: root.selected === index
              readonly property bool destructive: index === 1

              width: label.implicitWidth + Style.space(22)
              height: Style.space(28)
              radius: Style.space(6)
              color: isSelected
                ? (destructive ? Util.alpha(root.accent, 0.22) : Util.alpha(root.ink, 0.1))
                : "transparent"
              border.width: Math.max(1, Style.space(1))
              border.color: destructive
                ? (isSelected ? root.accent : Util.alpha(root.accent, 0.5))
                : (isSelected ? root.ink : Util.alpha(root.ink, 0.35))

              Text {
                id: label
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData
                color: parent.destructive ? root.accent : (parent.isSelected ? root.brightInk : root.ink)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = index
                onClicked: root.answer(index === 1 ? "confirm" : "cancel")
              }
            }
          }
        }
      }
    }
  }
}
