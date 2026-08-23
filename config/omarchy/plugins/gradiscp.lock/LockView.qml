import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property bool unlockSucceeded: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property int fieldWidth: 220
  readonly property int fieldHeight: 84
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0

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

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
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
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
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
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }
    }
  }
}
