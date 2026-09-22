import QtQuick
import qs.Commons

// The light lock's screensaver, drawn by the lock surface itself.
//
// Why a re-implementation and not the real one: the Omarchy screensaver is
// `ttfx --random-effect` inside a foot window (see omarchy-launch-screensaver),
// i.e. an ordinary Hyprland window - and while an ext-session-lock is up the
// compositor renders nothing but the lock surface. That is also why
// gradiscp.idle guards the screensaver with `omarchy-shell lock isLocked` and
// why omarchy-lock-light kills ttfx outright before locking. Of ttfx's ~40
// effects this copies the one that survives a rewrite: `matrix`.
//
// Cheap on purpose, since it may run for hours on battery: the falling is one
// GPU-driven y animation per column, and the only per-frame CPU work is the
// flicker timer re-rolling the glyphs of three columns every 140ms.
Item {
  id: root

  // Stop everything when the screensaver is not on screen - a paused
  // animation still costs nothing, a running one off-screen would not.
  property bool running: false

  clip: true

  // No "<", ">" or "&": the trail is StyledText markup, and those three
  // would be read as markup rather than drawn (seen as literal
  // `</font><br>` runs in the rain). No katakana either - JetBrainsMono has
  // none, so the fallback font breaks the monospace grid.
  readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%*+=/\\|[]{}~^"
  readonly property color trailColor: Color.lock.borderActive
  readonly property color headColor: Color.lock.text
  readonly property int glyphSize: Math.round(Style.font.heading * 1.25)
  readonly property int lineHeight: Math.round(glyphSize * 1.15)
  readonly property int columnWidth: Math.max(1, Math.ceil(glyphMetrics.advanceWidth))
  // Every second glyph column carries a drop (2026-09-21, was every one):
  // half the animated Text items, and the rain reads more like rain than a
  // wall of type. ~64 columns on this 1536px-wide (logical) panel.
  readonly property int columnPitch: columnWidth * 2
  readonly property int columnCount: Math.max(1, Math.floor(width / columnPitch))

  // StyledText takes plain "#rrggbb" only, so the trail is faded against the
  // black background here rather than with an alpha channel.
  function hexOf(c, factor) {
    function part(v) {
      var n = Math.max(0, Math.min(255, Math.round(v * 255 * factor)))
      return (n < 16 ? "0" : "") + n.toString(16)
    }
    return "#" + part(c.r) + part(c.g) + part(c.b)
  }

  function randomGlyph() {
    return glyphs.charAt(Math.floor(Math.random() * glyphs.length))
  }

  // Top of the drop is the oldest, dimmest glyph; the last one is the head.
  function trailMarkup(length) {
    var parts = []
    for (var i = 0; i < length; i++) {
      var t = (i + 1) / length
      var color = i === length - 1 ? hexOf(headColor, 1) : hexOf(trailColor, 0.12 + 0.88 * t * t)
      parts.push("<font color=\"" + color + "\">" + randomGlyph() + "</font>")
    }
    return parts.join("<br>")
  }

  TextMetrics {
    id: glyphMetrics
    font.family: Style.font.family
    font.pixelSize: root.glyphSize
    text: "0"
  }

  Repeater {
    id: columns
    model: root.columnCount

    delegate: Item {
      id: column

      required property int index

      width: root.columnWidth
      height: root.height
      x: index * root.columnPitch

      // Length, speed and phase are rolled once per column and then left
      // alone. Nothing may re-roll them while the column falls: touching a
      // running animation's properties restarts it, and doing that from a
      // ScriptAction inside that same animation recurses until the QML
      // engine throws "Maximum call stack size exceeded" and the shell hangs
      // (learned the hard way, 2026-09-20). Variety comes from the flicker
      // timer below instead, which only swaps glyphs.
      readonly property int glyphCount: 6 + Math.floor(Math.random() * 22)
      readonly property int dropHeight: glyphCount * root.lineHeight
      readonly property int gapMs: Math.floor(Math.random() * 2500)
      // Constant-ish speed per drop rather than constant duration, so a long
      // trail does not fall faster than a short one.
      readonly property int fallMs: Math.round((root.height + dropHeight) / (60 + Math.random() * 110) * 1000)
      // Where this column is in its first fall. Without it every column
      // starts at the top together and the screensaver opens on an empty
      // screen with one synchronized wave rolling down it.
      readonly property real firstProgress: Math.random()
      readonly property int firstY: Math.round(-dropHeight + firstProgress * (root.height + dropHeight))
      readonly property int firstMs: Math.max(1, Math.round(fallMs * (1 - firstProgress)))

      // Same drop, freshly rolled glyphs: keeps the column alive without
      // moving it or changing its height.
      function reglyph() {
        drop.text = root.trailMarkup(glyphCount)
      }

      Component.onCompleted: reglyph()

      Text {
        id: drop
        width: parent.width
        y: -column.dropHeight
        textFormat: Text.StyledText
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.font.family
        font.pixelSize: root.glyphSize
        lineHeight: root.lineHeight
        lineHeightMode: Text.FixedHeight
      }

      SequentialAnimation {
        running: root.running && root.height > 0

        // The partial first fall, then the same drop over and over.
        NumberAnimation {
          target: drop
          property: "y"
          from: column.firstY
          to: root.height
          duration: column.firstMs
          easing.type: Easing.Linear
        }

        SequentialAnimation {
          loops: Animation.Infinite

          PauseAnimation { duration: column.gapMs }
          NumberAnimation {
            target: drop
            property: "y"
            from: -column.dropHeight
            to: root.height
            duration: column.fallMs
            easing.type: Easing.Linear
          }
        }
      }
    }
  }

  Timer {
    running: root.running
    interval: 140
    repeat: true
    onTriggered: {
      for (var n = 0; n < 3; n++) {
        var item = columns.itemAt(Math.floor(Math.random() * root.columnCount))
        if (item) item.reglyph()
      }
    }
  }
}
