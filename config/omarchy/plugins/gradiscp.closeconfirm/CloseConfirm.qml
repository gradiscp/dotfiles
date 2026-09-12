import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// SUPER+W's "close anyway?" question, summoned by bin/window-close-guard when
// the terminal about to close still has something running in it:
//   omarchy-shell shell summon gradiscp.closeconfirm '{"process":"claude"}'
// Terminal-styled card ("B" of three mockups): a title strip, "$ <process>
// läuft noch", the question with a blinking block cursor, and bracketed
// options with the selected one inverted. Colors, type and spacing come from
// the theme tokens only, so it follows `omarchy theme set`.
// Keys: Tab / Shift+Tab / Left / Right switch, Enter picks, Escape cancels.
// The answer goes back to window-close-guard, which knows which window it was.
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
  readonly property color ink: Color.foreground
  readonly property color brightInk: Qt.lighter(Color.foreground, 1.15)
  readonly property color accent: Color.popups.border
  readonly property color cardColor: Qt.darker(Color.background, 1.5)
  // Opaque on purpose: the strip is drawn from two overlapping rectangles
  // (rounded + square), and a translucent fill doubled up where they overlap,
  // leaving the lower half visibly lighter than the upper.
  readonly property color stripColor: Qt.tint(root.cardColor, Util.alpha(root.ink, 0.05))
  readonly property int borderWidth: 2

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.process = payload.process || ""
    // Start on "Abbrechen", so a stray Enter keeps the window.
    root.selected = 0
    cursor.visible = true
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
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "gradiscp-closeconfirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

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
      id: card
      width: Style.space(460)
      height: strip.height + body.implicitHeight + root.borderWidth * 2
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: root.cardColor
      border.color: root.accent
      border.width: root.borderWidth

      // Swallow clicks on the card so only the scrim cancels.
      MouseArea { anchors.fill: parent; onClicked: {} }

      // Title strip. Rounded like the card on top, square at the bottom: a
      // fully rounded rectangle with its lower half covered by a square one.
      Item {
        id: strip
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.borderWidth }
        height: Style.space(30)

        Rectangle {
          anchors.fill: parent
          radius: Math.max(0, Style.cornerRadius - root.borderWidth)
          color: root.stripColor
        }
        Rectangle {
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: parent.height / 2
          color: root.stripColor
        }

        Text {
          anchors { left: parent.left; leftMargin: Style.space(14); verticalCenter: parent.verticalCenter }
          text: "window-close-guard"
          color: Util.alpha(root.ink, 0.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors { right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
          text: "SUPER+W"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Column {
        id: body
        anchors { top: strip.bottom; left: parent.left; right: parent.right }
        topPadding: Style.space(18)
        bottomPadding: Style.space(16)
        leftPadding: Style.space(20)
        rightPadding: Style.space(20)
        spacing: Style.space(12)

        Row {
          spacing: Style.space(8)
          Text {
            textFormat: Text.PlainText
            text: "$"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
          Text {
            textFormat: Text.PlainText
            text: root.process || "etwas"
            color: Util.alpha(root.ink, 0.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
          Text {
            textFormat: Text.PlainText
            text: "läuft noch"
            color: Util.alpha(root.ink, 0.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }

        Row {
          spacing: Style.space(8)
          Text {
            id: question
            textFormat: Text.PlainText
            text: "Fenster trotzdem schließen?"
            color: root.brightInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
          Rectangle {
            id: cursor
            width: Style.space(8)
            height: question.height
            color: root.accent

            Timer {
              interval: 550
              repeat: true
              running: root.opened
              onTriggered: cursor.visible = !cursor.visible
            }
          }
        }

        Row {
          topPadding: Style.space(6)
          spacing: Style.space(10)

          Repeater {
            model: ["[ Abbrechen ]", "[ Schließen ]"]

            Rectangle {
              required property int index
              required property string modelData

              readonly property bool isSelected: root.selected === index
              readonly property color tint: index === 1 ? root.accent : root.ink

              width: label.implicitWidth + Style.space(24)
              height: label.implicitHeight + Style.space(10)
              color: isSelected ? tint : "transparent"

              Text {
                id: label
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData
                color: parent.isSelected ? root.cardColor : parent.tint
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
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

        Text {
          topPadding: Style.space(4)
          textFormat: Text.PlainText
          text: "tab wechselt · enter wählt · esc bricht ab"
          color: Util.alpha(root.ink, 0.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
