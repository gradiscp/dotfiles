import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

// The "normal" lock screen, shown for SUPER+SHIFT+L and the idle auto-lock.
// Built from the stock omarchy.lock view, reworked: the theme wallpaper
// sharp (no blur), a clock in the bottom-left corner, and a transparent
// password field that stays invisible until the user starts typing, then
// fades/slides in. SUPER+L keeps the minimal LockView.qml - Service.qml picks
// between the two via its noBlank flag.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  // Set by a keystroke or click, cleared by concealTimer. The field is also
  // held up while there is text in it or a password check is in flight, so
  // it never vanishes under a half-typed password.
  property bool fieldRevealed: false
  readonly property bool fieldShown: fieldRevealed || authenticatingPassword || passwordInput.text.length > 0

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property int clockMargin: Math.round(Math.min(width, height) * 0.07)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
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

  function revealField() {
    if (!inputEnabled) return
    fieldRevealed = true
    concealTimer.restart()
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
    } else {
      // Next lock starts on the clean clock-only screen again.
      fieldRevealed = false
      concealTimer.stop()
    }
  }
  // A wrong password clears the field; keep it up long enough to read why.
  onFailureMessageChanged: {
    if (failureMessage.length > 0) revealField()
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Same source the bar's clock widget uses; minute precision is all a lock
  // screen needs and keeps it from waking up every second.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Timer {
    id: concealTimer
    interval: 3000
    repeat: false
    onTriggered: root.fieldRevealed = false
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    // The plain desktop wallpaper, deliberately unblurred.
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

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus(); root.revealField() }
      onPositionChanged: root.wakeRequested()
    }

    // Clock in the bottom-left corner. With the wallpaper no longer blurred,
    // the soft shadow is what keeps it legible over bright patches. It hands
    // the screen over to the password field: fades/sinks out as the field
    // comes in, and back once the field hides again - mirrored timings.
    Column {
      id: clockColumn
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.clockMargin
      anchors.bottomMargin: root.fieldShown ? root.clockMargin - 16 : root.clockMargin
      spacing: Math.round(Style.font.heading * 0.25)
      opacity: root.fieldShown ? 0 : 1

      Behavior on opacity { NumberAnimation { duration: root.fieldShown ? 240 : 420; easing.type: Easing.OutCubic } }
      Behavior on anchors.bottomMargin { NumberAnimation { duration: root.fieldShown ? 240 : 420; easing.type: Easing.OutCubic } }

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
      }

      Text {
        textFormat: Text.PlainText
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.display * 4)
        font.bold: true
      }

      Text {
        // Nudge the date in so its left edge lines up with the big digits'
        // visible edge rather than their side bearing.
        leftPadding: Math.round(Style.font.display * 0.15)
        textFormat: Text.PlainText
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.25)
      }
    }

    // Transparent field, invisible until revealed. It keeps receiving keys
    // at opacity 0 - opacity does not touch focus, only `visible` would -
    // so the first keystroke both types a character and brings it in.
    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: root.fieldShown ? 0 : 16
      // A dark but see-through fill (2026-09-16; was fully transparent),
      // so the dots and the border read against the unblurred wallpaper.
      color: Util.alpha(Color.background, 0.55)
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true
      opacity: root.fieldShown ? 1 : 0
      scale: root.fieldShown ? 1 : 0.94

      // Quick in, slower out.
      Behavior on opacity { NumberAnimation { duration: root.fieldShown ? 240 : 420; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: root.fieldShown ? 240 : 420; easing.type: Easing.OutCubic } }
      Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: root.fieldShown ? 240 : 420; easing.type: Easing.OutCubic } }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
            root.revealField()
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
          root.revealField()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
