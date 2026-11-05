import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "OsdModel.js" as OsdModel

Item {
  id: root

  property bool opened: false
  property string icon: ""
  property string message: ""
  property string iconKey: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1200

  readonly property bool mediaOsd: iconKey.indexOf("media") === 0 || iconKey.indexOf("player") === 0

  // The card is built out of measured columns instead of fixed widths, so it
  // keeps exactly `pad` between border and content on every side whatever
  // glyph or message it carries. Messages grow with their text up to
  // `maxMessageWidth` and elide beyond it.
  readonly property int pad: Style.space(16)
  readonly property int gap: Style.space(16)
  // A glyph next to a message reads airier than it measures: the icon outline
  // and the letterforms both fall away from their ink extremes, so the space
  // between them opens up well past the nominal gap. Text takes two thirds of
  // it; the progress bar's hard edge keeps the full gap.
  readonly property int messageGap: Math.round(root.gap * 2 / 3)
  readonly property int barWidth: Style.space(142)
  readonly property int maxMessageWidth: root.mediaOsd ? Style.space(325) : Style.space(190)

  // Nerd Font glyphs draw well outside their monospace cell, so the icon
  // column is measured by ink rather than by advance width. Progress OSDs pin
  // it to the widest glyph the model can return, so the bar doesn't shift when
  // volume crosses an icon threshold.
  readonly property int iconInkWidth: Math.ceil(iconMetrics.tightBoundingRect.width)
  readonly property int iconWidth: root.hasProgress
    ? Math.max(root.iconInkWidth, Math.ceil(widestIconMetrics.tightBoundingRect.width))
    : root.iconInkWidth
  // Same idea for the readout: it is as wide as the longest percentage so the
  // digits don't jitter between 9% and 100%.
  readonly property int valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth, messageMetrics.advanceWidth))
  readonly property int messageWidth: Math.min(Math.ceil(messageMetrics.advanceWidth), root.maxMessageWidth)
  readonly property int contentWidth: root.hasProgress
    ? root.iconWidth + root.gap + root.barWidth + root.gap + root.valueWidth
    : (root.message === "" ? root.iconWidth : root.iconWidth + root.messageGap + root.messageWidth)

  function iconFor(name, percent) {
    return OsdModel.iconFor(name, percent)
  }

  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var next = OsdModel.stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration, Commons.I18n.formatNumber)
    // Update before opening so a fresh OSD starts at its new value; only
    // subsequent updates while it remains open animate the progress bar.
    iconKey = next.iconKey
    maxValue = next.maxValue
    hasProgress = next.hasProgress
    value = next.value
    message = next.message
    icon = next.icon
    duration = next.duration
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value), p.max === undefined ? "100" : String(p.max), p.progressText || "", p.duration === undefined ? "1200" : String(p.duration))
    } catch (e) {}
  }

  function close() { opened = false }

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  TextMetrics {
    id: messageMetrics
    font.family: Style.font.family
    font.bold: true
    font.pixelSize: Style.font.title
    text: root.message
  }

  TextMetrics {
    id: valueMetrics
    font: messageMetrics.font
    text: Commons.I18n.formatNumber(100) + "%"
  }

  TextMetrics {
    id: iconMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.displayLarge
    text: root.icon
  }

  TextMetrics {
    id: widestIconMetrics
    font: iconMetrics.font
    text: OsdModel.widestIcon
  }

  ShellIpc {
    target: "osd"
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-osd"
    // Visual-only surface: keep the layer-shell input region empty so the OSD
    // never blocks clicks to the desktop below it.
    mask: Region {}

    BorderSurface {
      id: card
      width: card.borderLeft + root.pad + root.contentWidth + root.pad + card.borderRight
      height: card.borderTop + root.pad + Style.font.displayLarge + root.pad + card.borderBottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(67)
      color: Qt.rgba(0.114, 0.114, 0.169, 0.90) // #1d1d2b frosted glass
      borderSpec: Border.flat(Qt.rgba(0.75, 0.25, 1.0, 0.25), 1) // subtle mauve outline
      radius: Math.round(height / 2) // Sleek capsule pill
      opacity: root.opened ? 1 : 0

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.70)
        shadowBlur: 0.65
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
        shadowOpacity: 1.0
      }

      Row {
        anchors.fill: parent
        anchors.topMargin: card.borderTop + root.pad
        anchors.rightMargin: card.borderRight + root.pad
        anchors.bottomMargin: card.borderBottom + root.pad
        anchors.leftMargin: card.borderLeft + root.pad
        spacing: root.hasProgress ? root.gap : root.messageGap

        Item {
          width: root.iconWidth
          height: parent.height

          Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: Component {
              Item {
                id: iconEffectRoot
                property var source

                MultiEffect {
                  anchors.fill: parent
                  source: iconEffectRoot.source
                  autoPaddingEnabled: false
                  shadowEnabled: true
                  shadowColor: Qt.color("#00a8ff") // Electric Sapphire
                  shadowBlur: 0.40
                  shadowScale: 1.0
                  shadowOpacity: 1.0
                }
                MultiEffect {
                  anchors.fill: parent
                  source: iconEffectRoot.source
                  autoPaddingEnabled: false
                  shadowEnabled: true
                  shadowColor: Qt.color("#00a8ff")
                  shadowBlur: 0.18
                  shadowScale: 1.0
                  shadowOpacity: 1.0
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              // Sit the glyph's ink flush in the column, centered when the
              // column is wider than this particular glyph.
              x: Math.round((root.iconWidth - root.iconInkWidth) / 2 - iconMetrics.tightBoundingRect.x)
              anchors.verticalCenter: parent.verticalCenter
              text: root.icon
              font: iconMetrics.font
              color: "#ffffff"
            }
          }
        }

        Rectangle {
          visible: root.hasProgress
          width: root.barWidth
          height: Style.space(8)
          radius: height / 2
          anchors.verticalCenter: parent.verticalCenter
          color: Qt.rgba(1, 1, 1, 0.12)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.05)

          Rectangle {
            // Anchored so a right-to-left layout fills from the right.
            anchors.left: parent.left
            height: parent.height
            width: parent.width * (root.hasProgress ? Math.max(0.0, Math.min(1.0, root.value / root.maxValue)) : 0)
            radius: height / 2

            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "#00a8ff" } // Electric Sapphire
              GradientStop { position: 1.0; color: "#c040ff" } // Electric Mauve
            }

            layer.enabled: true
            layer.effect: Component {
              Item {
                id: progressEffectRoot
                property var source

                MultiEffect {
                  anchors.fill: parent
                  source: progressEffectRoot.source
                  autoPaddingEnabled: false
                  shadowEnabled: true
                  shadowColor: Qt.color("#00a8ff")
                  shadowBlur: 0.35
                  shadowScale: 1.0
                  shadowOpacity: 0.85
                }
              }
            }

            Behavior on width {
              enabled: root.opened
              NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.message !== ""
          width: root.hasProgress ? root.valueWidth : root.messageWidth
          // The readout hugs the card edge so a short percentage doesn't leave
          // a hole in the padding; the slack lands in the gap after the bar.
          horizontalAlignment: root.hasProgress ? Text.AlignRight : Text.AlignLeft
          anchors.verticalCenter: parent.verticalCenter
          text: root.message
          font: messageMetrics.font
          color: "#ffffff"
          elide: Text.ElideRight
          maximumLineCount: 1

          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.60)
            shadowBlur: 0.20
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
            shadowOpacity: 0.80
          }
        }
      }
    }
  }
}
