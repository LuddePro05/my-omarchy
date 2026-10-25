import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
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

  property int updateTrigger: 0

  readonly property var displayedWorkspaces: {
    var _t = root.updateTrigger
    var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    var workspaces = Hyprland.workspaces.values
    var toplevels = Hyprland.toplevels.values

    var active = []

    for (var i = 0; i < workspaces.length; i++) {
      var ws = workspaces[i]
      if (ws && ws.id > 0 && ws.id <= 10) {
        if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) {
          if (active.indexOf(ws.id) === -1) {
            active.push(ws.id)
          }
        }
      }
    }

    for (var j = 0; j < toplevels.length; j++) {
      var top = toplevels[j]
      if (top && top.workspace && top.workspace.id > 0 && top.workspace.id <= 10) {
        if (active.indexOf(top.workspace.id) === -1) {
          active.push(top.workspace.id)
        }
      }
    }

    var maxActive = 1
    for (var k = 0; k < active.length; k++) {
      if (active[k] > maxActive) maxActive = active[k]
    }

    var end = Math.min(10, maxActive + 1)

    // Ensure the currently focused workspace is visible if user navigated to it
    if (focusedId > 0 && focusedId <= 10 && focusedId > end) {
      end = focusedId
    }

    var ids = []
    for (var id = 1; id <= end; id++) {
      ids.push(id)
    }
    return ids
  }

  function workspaceIds() {
    return root.displayedWorkspaces
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
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
    var index = ids.indexOf(root.focusedWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // The focused workspace shows its layout: a square tiles, a circle scrolls,
  // and a triangle floats. Clicking it cycles to the next one, as Super + L does.
  property string focusedMode: "dwindle"
  property bool modeStale: false

  function modeGlyph(mode) {
    if (mode === "scrolling") return "\uDB81\uDF65"
    if (mode === "floating") return "\uDB81\uDD36"
    return "\uDB85\uDCFB"
  }

  // A layout only changes through the layout commands, which ask for a refresh,
  // or a config reload, so each workspace's mode is read once and cached rather
  // than running the script on every workspace switch.
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0

  function focusedWorkspaceId() {
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  }

  function showFocusedMode() {
    var mode = root.modeCache[root.focusedWorkspaceId()]
    if (mode !== undefined) root.focusedMode = mode
    else readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.focusedWorkspaceId()
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

  function cycleLayout() {
    if (root.bar) root.bar.run("omarchy-hyprland-workspace-layout-toggle")
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      root.showFocusedMode()
      root.updateTrigger++
    }
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") {
        root.refresh()
      } else {
        root.updateTrigger++
      }
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        // A read that started before a refresh may predate the change.
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.focusedWorkspaceId()) root.focusedMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      // Deferred: the process still reports running while it signals exit.
      Qt.callLater(root.showFocusedMode)
    }
  }

  // Super + L and the default layout change the mode without a focus change,
  // so they ask every bar to read it again.
  ShellIpc {
    target: "omarchy.workspaces"

    function refresh(): void { root.broadcast("refresh") }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  // The bar's electric gradient, spread across the workspaces from the left
  // (mauve) to the right (sapphire). Each workspace glows in the hue of its
  // own place on the row, so the active number and its underline pill keep
  // the same left-to-right flow as the bar's other gradient elements.
  function workspaceGlowColor(index) {
    var c1 = Qt.color("#c040ff") // Electric Mauve
    var c2 = Qt.color("#00a8ff") // Electric Sapphire
    var total = root.displayedWorkspaces.length
    var t = total <= 1 ? 0.0 : Math.max(0.0, Math.min(1.0, index / (total - 1)))
    return Qt.rgba(
      c1.r + (c2.r - c1.r) * t,
      c1.g + (c2.g - c1.g) * t,
      c1.b + (c2.b - c1.b) * t,
      1.0
    )
  }

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.displayedWorkspaces.length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.displayedWorkspaces

      WidgetButton {
        id: button
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property int workspaceIndex: root.displayedWorkspaces.indexOf(modelData)
        readonly property color glowColor: root.workspaceGlowColor(workspaceIndex)

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        active: button.focused
        // The number stays pure white; its place in the row supplies the hue
        // of the electric aura around it and its underline pill.
        activeColor: "#ffffff"
        foreground: Commons.Color.foreground
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize

        // 3-pass multi-layer neon aura: wide electric halo, vibrant body, and
        // a dense core hugging the white sign. Only the focused workspace
        // glows, matching the active pill's place in the gradient.
        layer.enabled: button.focused
        layer.effect: Component {
          Item {
            id: workspaceGlowRoot
            property var source

            // Pass 1: wide electric aura
            MultiEffect {
              anchors.fill: parent
              source: workspaceGlowRoot.source
              autoPaddingEnabled: true
              shadowEnabled: true
              shadowColor: button.glowColor
              shadowBlur: 0.95
              shadowScale: 1.12
              shadowVerticalOffset: 0
              shadowHorizontalOffset: 0
              shadowOpacity: 1.0
            }

            // Pass 2: vibrant neon body
            MultiEffect {
              anchors.fill: parent
              source: workspaceGlowRoot.source
              autoPaddingEnabled: true
              shadowEnabled: true
              shadowColor: button.glowColor
              shadowBlur: 0.50
              shadowScale: 1.06
              shadowVerticalOffset: 0
              shadowHorizontalOffset: 0
              shadowOpacity: 1.0
            }

            // Pass 3: dense core halo hugging the white sign and pill
            MultiEffect {
              anchors.fill: parent
              source: workspaceGlowRoot.source
              autoPaddingEnabled: true
              shadowEnabled: true
              shadowColor: button.glowColor
              shadowBlur: 0.20
              shadowScale: 1.0
              shadowVerticalOffset: 0
              shadowHorizontalOffset: 0
              shadowOpacity: 1.0
            }
          }
        }

        onPressed: function() {
          if (focused) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        Rectangle {
          id: underline
          visible: button.focused
          anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
          anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
          anchors.bottom: root.vertical ? undefined : parent.bottom
          anchors.bottomMargin: root.vertical ? 0 : Style.space(2)
          anchors.right: root.vertical ? parent.right : undefined
          anchors.rightMargin: root.vertical ? Style.space(2) : 0
          width: root.vertical ? Style.space(2) : Style.space(12)
          height: root.vertical ? Style.space(12) : Style.space(2)
          radius: Math.min(width, height) / 2
          gradient: Gradient {
            orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0.0; color: "#c040ff" }
            GradientStop { position: 1.0; color: "#00a8ff" }
          }

          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowBlur: 0.15
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
          }
        }
      }
    }
  }
}
