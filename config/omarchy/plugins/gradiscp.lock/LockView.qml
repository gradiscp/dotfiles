import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool authenticatingPassword: false
  property bool unlockSucceeded: false
  property string failureMessage: ""
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property int fieldWidth: 220
  readonly property int fieldHeight: 84
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)

  // The light lock never blanks the panel, so without this it sits on the
  // same still screenshot for hours. MatrixRain.qml says why the real ttfx
  // screensaver cannot be shown over a session lock. Three minutes, matching
  // what the desktop screensaver would have done.
  property bool screensaverActive: false
  readonly property int screensaverDelay: 180000
  // After this long the rain stops and the still icon comes back: a lock
  // left alone for the night should not render ~64 animations at 60fps
  // until morning. Input still restarts the cycle. Panel stays on either way.
  readonly property int screensaverMaxRun: 1800000

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when a
  // fresh screenshot is captured mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  // Any input ends the screensaver and starts the three minutes over.
  // Returns true when it was the input that ended it - that one is swallowed,
  // exactly like the real screensaver, whose first keystroke only exits it
  // instead of landing in the password.
  function dismissScreensaver(reason) {
    var wasActive = screensaverActive
    if (wasActive) console.log("omarchy lock screensaver dismissed: " + reason)
    screensaverActive = false
    if (inputEnabled) screensaverTimer.restart()
    return wasActive
  }

  // `positionChanged` is not the same as "the mouse moved": Qt Quick also
  // delivers a hover event at the *unchanged* cursor position whenever the
  // scene under the cursor changes - and the screensaver fading in is such
  // a change. That one event ended every screensaver a second after it
  // started (seen 2026-09-20 in the journal: a single `pointer x,y` dismiss,
  // no hand on the mouse). So the pointer only counts once it has actually
  // travelled a few pixels from where it was last seen.
  property real lastPointerX: -1
  property real lastPointerY: -1

  function pointerMoved(x, y) {
    var moved = lastPointerX >= 0 && (Math.abs(x - lastPointerX) > 3 || Math.abs(y - lastPointerY) > 3)
    lastPointerX = x
    lastPointerY = y
    if (!moved) return
    wakeRequested()
    dismissScreensaver("pointer " + x + "," + y)
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) {
      Qt.callLater(forcePasswordFocus)
      screensaverTimer.restart()
    } else {
      screensaverTimer.stop()
      screensaverActive = false
    }
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) {
      Qt.callLater(forcePasswordFocus)
      screensaverTimer.restart()
    }
  }

  Timer {
    id: screensaverTimer
    interval: root.screensaverDelay
    repeat: false
    onTriggered: if (root.inputEnabled) root.screensaverActive = true
  }

  Timer {
    id: screensaverStopTimer
    interval: root.screensaverMaxRun
    repeat: false
    running: root.screensaverActive
    onTriggered: {
      console.log("omarchy lock screensaver stopped after " + (root.screensaverMaxRun / 60000) + " min")
      root.screensaverActive = false
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    // A live screenshot of the desktop at the moment of locking (grabbed by
    // Service.qml before the session lock surface takes over), not the
    // static theme wallpaper.
    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 0.3
      blurMax: 32
      blurMultiplier: 1.0
      contrast: -0.03
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.dismissScreensaver("click"); root.forcePasswordFocus() }
      onPositionChanged: root.pointerMoved(mouseX, mouseY)
    }

    // Just the lock-in-a-circle over the blurred screenshot. Typing is
    // blind (no dots, no field chrome, like a terminal sudo prompt) - the
    // circle fades out while a character is held, and comes back colored
    // once there's a result: green on correct, red on wrong.
    Rectangle {
      id: lockIconBadge
      anchors.centerIn: parent
      width: 84
      height: 84
      radius: width / 2
      color: Qt.rgba(0, 0, 0, 0.3)
      border.width: 2
      border.color: root.unlockSucceeded ? "#5fd07a"
        : root.failureMessage.length > 0 ? "#e05a5a"
        : Qt.rgba(1, 1, 1, 0.55)
      opacity: keystrokeFlashTimer.running && !root.authenticatingPassword
        && !root.unlockSucceeded && root.failureMessage.length === 0 ? 0 : 1

      Behavior on border.color { ColorAnimation { duration: 150 } }
      Behavior on opacity { NumberAnimation { duration: 60 } }

      // Brief blip per keystroke, not hidden for the whole time you're
      // typing - restarted from passwordInput.onTextChanged below.
      Timer {
        id: keystrokeFlashTimer
        interval: 120
      }

      Image {
        anchors.centerIn: parent
        width: 36
        height: 36
        source: "lock-icon.svg"
        sourceSize: Qt.size(36, 36)
      }
    }

    // Screensaver: fades the screenshot and the icon out behind black and
    // rains over it. Loaded only while it is on screen, so an untouched lock
    // carries no idle columns around. Input dismisses it, see
    // dismissScreensaver().
    Rectangle {
      id: screensaverCover
      anchors.fill: parent
      color: "black"
      opacity: root.screensaverActive ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        NumberAnimation { duration: root.screensaverActive ? 1200 : 400; easing.type: Easing.InOutQuad }
      }

      Loader {
        anchors.fill: parent
        active: screensaverCover.visible
        sourceComponent: MatrixRain { running: root.screensaverActive }
      }
    }

    // Invisible hit target: captures keystrokes, shows nothing itself. All
    // feedback is the circle above (fade while typing, red/green on result).
    Item {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent

      TextInput {
        id: passwordInput
        anchors.fill: parent
        activeFocusOnPress: true
        opacity: 0
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 0
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          keystrokeFlashTimer.restart()
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (root.dismissScreensaver("key")) {
            // Eat it, so TextInput inserts no character: the key that ends
            // the screensaver must not become the first password character.
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }
    }
  }
}
