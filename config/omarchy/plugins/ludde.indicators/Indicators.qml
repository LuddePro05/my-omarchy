import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.indicators"

  readonly property var defaultIndicatorEntries: [ "PasswordlessSudo", "ScreenRecording", "RemoteSession", "Reminder", "NightLight", "Dnd", "StayAwake" ]
  readonly property var indicatorEntries: indicatorEntriesFromSettings(settings)
  property var activeIndicatorIds: []
  property var indicatorActiveStates: ({})
  property bool indicatorAreaHovered: false
  property bool indicatorItemHovered: false
  readonly property bool alwaysShowIndicators: setting("alwaysShow", false) === true
  readonly property bool revealInactiveIndicators: alwaysShowIndicators || indicatorAreaHovered || indicatorItemHovered || (bar && bar.centerSectionRevealHeld === true && bar.centerHoverRevealSuppressed !== true)
  // The active block sits against the widget's fixed edge, and everything that
  // grows the widget (revealed inactive icons, newly active ones) goes on its
  // far side, so the icons already showing keep their click targets. A
  // centered widget grows both ways and keeps the end-fixed arrangement.
  readonly property bool fixedAtStart: fixedEdge === "start"

  // A cloned widget receives a plugin-scoped bar facade, which deliberately
  // does not carry the narrow first-party service proxies the built-in
  // indicators use. The host bar injects its own service-capable facade as
  // `hostShell` for widgets that opt in, so the clone still reflects the real
  // toggles (night light, DND, idle and remote session).
  property var hostShell: null
  readonly property var shellRoot: {
    if (hostShell && typeof hostShell.firstPartyServiceFor === "function") return hostShell
    if (root.bar && root.bar.shell && typeof root.bar.shell.firstPartyServiceFor === "function")
      return root.bar.shell
    return null
  }

  signal refreshRequested()

  ListModel { id: activeIndicatorModel }

  // The inactive indicators in the order they show. Facing the other way, the
  // widget mirrors them along with its blocks, so they read outward from the
  // active block as they do from the other side. Turned around by moves, so no
  // indicator is built again.
  ListModel { id: inactiveIndicatorModel }
  property string inactiveIndicatorJson: ""
  property bool inactiveIndicatorsMirrored: false

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (Util.isPlainObject(entry)) {
      var id = entry["id"]
      if (id !== undefined && id !== null && String(id) !== "") return String(id)
    }
    return ""
  }

  function entrySettings(entry) {
    if (!Util.isPlainObject(entry)) return {}
    var copy = {}
    for (var key in entry) {
      if (key === "id") continue
      copy[key] = entry[key]
    }
    return copy
  }

  function indicatorEntriesFromSettings(settings) {
    var source = defaultIndicatorEntries
    if (settings.items && typeof settings.items.length === "number" && settings.items.length > 0) source = settings.items
    else if (settings.indicators && typeof settings.indicators.length === "number" && settings.indicators.length > 0) source = settings.indicators

    var result = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i]
      if (typeof item !== "string" && item !== null && typeof item === "object") {
        try {
          item = JSON.parse(JSON.stringify(item))
        } catch (error) {
        }
      }
      var id = entryId(item)
      if (id !== "") result.push(item)
    }
    return result
  }

  function setIndicatorAreaHovered(hovered) {
    indicatorAreaHovered = hovered
    if (hovered) indicatorHideTimer.stop()
    else indicatorHideTimer.restart()
  }

  function setIndicatorItemHovered(hovered) {
    if (hovered) {
      indicatorItemHovered = true
      indicatorHideTimer.stop()
    } else {
      indicatorHideTimer.restart()
    }
  }

  function hasIndicatorId(id) {
    for (var i = 0; i < indicatorEntries.length; i++) {
      if (entryId(indicatorEntries[i]) === id) return true
    }
    return false
  }

  function entryForId(id) {
    for (var i = 0; i < indicatorEntries.length; i++) {
      var entry = indicatorEntries[i]
      if (entryId(entry) === id) return entry
    }

    return { id: id }
  }

  function activeModelIndex(id) {
    for (var i = 0; i < activeIndicatorModel.count; i++) {
      if (activeIndicatorModel.get(i).activeId === id) return i
    }
    return -1
  }

  function copyActiveStates() {
    var states = {}
    for (var id in indicatorActiveStates) {
      if (indicatorActiveStates[id] === true) states[id] = true
    }
    return states
  }

  function orderedActiveIds(states, preferredOrder) {
    var ids = []

    for (var i = 0; i < preferredOrder.length; i++) {
      var id = preferredOrder[i]
      if (ids.indexOf(id) === -1 && hasIndicatorId(id) && states[id] === true) ids.push(id)
    }

    return ids
  }

  function syncActiveIndicatorModel() {
    for (var i = activeIndicatorModel.count - 1; i >= 0; i--) {
      if (activeIndicatorIds.indexOf(activeIndicatorModel.get(i).activeId) === -1)
        activeIndicatorModel.remove(i)
    }

    for (var j = 0; j < activeIndicatorIds.length; j++) {
      var id = activeIndicatorIds[j]
      var index = activeModelIndex(id)
      if (index === -1) activeIndicatorModel.insert(j, { activeId: id })
      else if (index !== j) activeIndicatorModel.move(index, j, 1)
    }
  }

  function setIndicatorActive(entry, active) {
    var id = entryId(entry)
    if (id === "") return

    var states = copyActiveStates()
    if (active) states[id] = true
    else delete states[id]

    indicatorActiveStates = states

    var ids = orderedActiveIds(states, activeIndicatorIds)
    // Newcomers go on the side of the active block away from the fixed edge.
    // The other side would shove everything already showing sideways.
    if (active && ids.indexOf(id) === -1 && hasIndicatorId(id)) {
      if (fixedAtStart) ids.push(id)
      else ids.unshift(id)
    }
    activeIndicatorIds = ids
    syncActiveIndicatorModel()
  }

  function syncActiveIndicatorOrder() {
    activeIndicatorIds = orderedActiveIds(indicatorActiveStates, activeIndicatorIds)
    syncActiveIndicatorModel()
  }

  function syncInactiveIndicatorModel() {
    var json = JSON.stringify(indicatorEntries)
    if (json !== inactiveIndicatorJson) {
      inactiveIndicatorJson = json
      inactiveIndicatorModel.clear()
      inactiveIndicatorsMirrored = false
      for (var i = 0; i < indicatorEntries.length; i++)
        inactiveIndicatorModel.append({ entryJson: JSON.stringify(indicatorEntries[i]) })
    }
    if (inactiveIndicatorsMirrored === fixedAtStart) return
    for (var j = 1; j < inactiveIndicatorModel.count; j++) inactiveIndicatorModel.move(j, 0, 1)
    inactiveIndicatorsMirrored = fixedAtStart
  }

  function refresh() { root.refreshRequested() }

  onIndicatorEntriesChanged: {
    syncActiveIndicatorOrder()
    syncInactiveIndicatorModel()
  }
  onFixedAtStartChanged: syncInactiveIndicatorModel()

  // Only the tree for the current orientation exists (see orientationLoader
  // below); its wrapper keeps the stock sizing expressions, so the root's
  // implicit size still follows the blocks synchronously rather than waiting
  // on a positioner's polish.
  implicitWidth: orientationLoader.item ? orientationLoader.item.implicitWidth : 0
  implicitHeight: orientationLoader.item ? orientationLoader.item.implicitHeight : 0

  ShellIpc {
    target: "omarchy.indicators"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Timer {
    id: indicatorHideTimer
    interval: 120
    onTriggered: {
      if (!root.indicatorAreaHovered)
        root.indicatorItemHovered = false
    }
  }

  Component.onCompleted: {
    syncInactiveIndicatorModel()
    root.refreshRequested()
  }

  // Instantiating both orientation trees and toggling `visible` doubled every
  // indicator per bar (and every process an indicator spawns, once per
  // monitor). Load only the tree that matches the bar orientation instead.
  Loader {
    id: orientationLoader
    sourceComponent: root.vertical ? verticalIndicatorsTree : horizontalIndicatorsTree
  }

  // The two blocks are placed by hand rather than by a Row or Column: a
  // Column cannot reverse its order, and the inactive area has to go on
  // whichever side is away from the fixed edge.
  Component {
    id: horizontalIndicatorsTree

    Item {
      implicitWidth: activeHorizontalBlock.implicitWidth + inactiveHorizontalArea.implicitWidth
      implicitHeight: Math.max(activeHorizontalBlock.implicitHeight, inactiveHorizontalArea.implicitHeight)
      width: implicitWidth
      height: implicitHeight

      HoverHandler {
        onHoveredChanged: root.setIndicatorAreaHovered(hovered)
      }

      Item {
        id: inactiveHorizontalArea

        x: root.fixedAtStart ? activeHorizontalBlock.width : 0
        implicitWidth: root.revealInactiveIndicators ? inactiveHorizontalBlock.implicitWidth : 0
        implicitHeight: Math.max(inactiveHorizontalBlock.implicitHeight, root.barSize)
        width: implicitWidth
        height: implicitHeight
        clip: true

        IndicatorBlock {
          id: inactiveHorizontalBlock
          anchors.verticalCenter: parent.verticalCenter
          indicatorsModule: root
          indicatorModel: inactiveIndicatorModel
          indicatorBlock: "inactive"
          horizontal: true
          reportActiveState: !root.vertical
        }

        HoverHandler {
          onHoveredChanged: root.setIndicatorAreaHovered(hovered)
        }
      }

      ActiveIndicatorBlock {
        id: activeHorizontalBlock
        x: root.fixedAtStart ? 0 : inactiveHorizontalArea.width
        indicatorsModule: root
        indicatorModel: activeIndicatorModel
        horizontal: true
        reportActiveState: !root.vertical
      }
    }
  }

  Component {
    id: verticalIndicatorsTree

    Item {
      implicitWidth: Math.max(activeVerticalBlock.implicitWidth, inactiveVerticalArea.implicitWidth)
      implicitHeight: activeVerticalBlock.implicitHeight + inactiveVerticalArea.implicitHeight
      width: implicitWidth
      height: implicitHeight

      HoverHandler {
        onHoveredChanged: root.setIndicatorAreaHovered(hovered)
      }

      Item {
        id: inactiveVerticalArea

        y: root.fixedAtStart ? activeVerticalBlock.height : 0
        implicitWidth: Math.max(inactiveVerticalBlock.implicitWidth, root.barSize)
        implicitHeight: root.revealInactiveIndicators ? inactiveVerticalBlock.implicitHeight : 0
        width: implicitWidth
        height: implicitHeight
        clip: true

        IndicatorBlock {
          id: inactiveVerticalBlock
          anchors.horizontalCenter: parent.horizontalCenter
          indicatorsModule: root
          indicatorModel: inactiveIndicatorModel
          indicatorBlock: "inactive"
          horizontal: false
          reportActiveState: root.vertical
        }

        HoverHandler {
          onHoveredChanged: root.setIndicatorAreaHovered(hovered)
        }
      }

      ActiveIndicatorBlock {
        id: activeVerticalBlock
        y: root.fixedAtStart ? 0 : inactiveVerticalArea.height
        indicatorsModule: root
        indicatorModel: activeIndicatorModel
        horizontal: false
        reportActiveState: root.vertical
      }
    }
  }

  HoverHandler {
    onHoveredChanged: root.setIndicatorAreaHovered(hovered)
  }

  component ActiveIndicatorBlock: Item {
    id: activeIndicatorBlockRoot

    property var indicatorModel: null
    property var indicatorsModule: null
    property bool horizontal: true
    property bool reportActiveState: false

    implicitWidth: blockLoader.item ? blockLoader.item.implicitWidth : 0
    implicitHeight: blockLoader.item ? blockLoader.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    Loader {
      id: blockLoader

      anchors.centerIn: parent
      sourceComponent: activeIndicatorBlockRoot.horizontal ? horizontalActiveIndicatorBlock : verticalActiveIndicatorBlock
    }

    Component {
      id: horizontalActiveIndicatorBlock

      Row {
        spacing: 0

        Repeater {
          model: activeIndicatorBlockRoot.indicatorModel

          IndicatorLoader {
            required property string activeId
            indicatorsModule: activeIndicatorBlockRoot.indicatorsModule
            entry: activeIndicatorBlockRoot.indicatorsModule.entryForId(activeId)
            indicatorBlock: "active"
            reportActiveState: activeIndicatorBlockRoot.reportActiveState
          }
        }
      }
    }

    Component {
      id: verticalActiveIndicatorBlock

      Column {
        spacing: 0

        Repeater {
          model: activeIndicatorBlockRoot.indicatorModel

          IndicatorLoader {
            required property string activeId
            indicatorsModule: activeIndicatorBlockRoot.indicatorsModule
            entry: activeIndicatorBlockRoot.indicatorsModule.entryForId(activeId)
            indicatorBlock: "active"
            reportActiveState: activeIndicatorBlockRoot.reportActiveState
          }
        }
      }
    }
  }

  component IndicatorBlock: Item {
    id: indicatorBlockRoot

    property var indicatorModel: null
    property var indicatorsModule: null
    property string indicatorBlock: "active"
    property bool horizontal: true
    property bool reportActiveState: false

    implicitWidth: blockLoader.item ? blockLoader.item.implicitWidth : 0
    implicitHeight: blockLoader.item ? blockLoader.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    Loader {
      id: blockLoader

      anchors.centerIn: parent
      sourceComponent: indicatorBlockRoot.horizontal ? horizontalIndicatorBlock : verticalIndicatorBlock
    }

    Component {
      id: horizontalIndicatorBlock

      Row {
        spacing: 0

        Repeater {
          model: indicatorBlockRoot.indicatorModel

          IndicatorLoader {
            required property string entryJson
            indicatorsModule: indicatorBlockRoot.indicatorsModule
            entry: JSON.parse(entryJson)
            indicatorBlock: indicatorBlockRoot.indicatorBlock
            reportActiveState: indicatorBlockRoot.reportActiveState
          }
        }
      }
    }

    Component {
      id: verticalIndicatorBlock

      Column {
        spacing: 0

        Repeater {
          model: indicatorBlockRoot.indicatorModel

          IndicatorLoader {
            required property string entryJson
            indicatorsModule: indicatorBlockRoot.indicatorsModule
            entry: JSON.parse(entryJson)
            indicatorBlock: indicatorBlockRoot.indicatorBlock
            reportActiveState: indicatorBlockRoot.reportActiveState
          }
        }
      }
    }
  }

  component IndicatorLoader: Item {
    id: indicatorSlot

    required property var entry
    property var indicatorsModule: null
    required property string indicatorBlock
    property bool reportActiveState: false
    property bool activeStateObserved: false
    readonly property string indicatorId: root.entryId(entry)
    readonly property var indicatorSettings: root.entrySettings(entry)
    readonly property var barRef: root.bar

    // The same electric gradient the workspaces and the bar icons carry,
    // spread across the indicators in their configured order. An indicator
    // keeps its hue wherever it sits: in the active block, or among the
    // inactive ones a hover reveals.
    readonly property color glowColor: {
      var list = root.indicatorEntries
      var total = list.length
      var index = 0
      for (var i = 0; i < total; i++) {
        if (root.entryId(list[i]) === indicatorId) {
          index = i
          break
        }
      }
      var c1 = Qt.color("#c040ff") // Electric Mauve
      var c2 = Qt.color("#00a8ff") // Electric Sapphire
      var t = total <= 1 ? 0.0 : index / (total - 1)
      return Qt.rgba(
        c1.r + (c2.r - c1.r) * t,
        c1.g + (c2.g - c1.g) * t,
        c1.b + (c2.b - c1.b) * t,
        1.0
      )
    }

    // True only for an active icon. Inactive icons keep a single soft pass so
    // their dimmed aura does not stack back up to active brightness.
    readonly property bool iconActive: indicatorSource.item
      ? indicatorSource.item.effectiveActive === true : false

    implicitWidth: indicatorSource.item && indicatorSource.item.visible ? indicatorSource.item.implicitWidth : 0
    implicitHeight: indicatorSource.item && indicatorSource.item.visible ? indicatorSource.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    onEntryChanged: {
      activeStateObserved = false
      injectProps()
      syncActiveState()
    }
    onIndicatorBlockChanged: injectProps()
    onIndicatorSettingsChanged: injectProps()
    onIndicatorsModuleChanged: {
      injectProps()
      syncActiveState()
    }
    onReportActiveStateChanged: syncActiveState()
    onBarRefChanged: injectProps()

    Loader {
      id: indicatorSource

      anchors.fill: parent
      source: indicatorSlot.indicatorId ? Qt.resolvedUrl("indicators/" + indicatorSlot.indicatorId + ".qml") : ""

      // The aura rides the icon's own opacity, so an inactive indicator's
      // glow is dimmed to 0.45 with its glyph while an active one burns at
      // full strength.
      layer.enabled: item !== null && item.visible
      layer.effect: Component {
        Item {
          id: indicatorGlowEffect
          property var source

          // Pass 1: Wide electric glow aura
          MultiEffect {
            anchors.fill: parent
            source: indicatorGlowEffect.source
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: indicatorSlot.glowColor
            shadowBlur: 0.95
            shadowScale: 1.08
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
            shadowOpacity: indicatorSlot.iconActive ? 1.0 : 0.65
          }

          // Pass 2: Mid vibrant neon aura
          MultiEffect {
            anchors.fill: parent
            visible: indicatorSlot.iconActive
            source: indicatorGlowEffect.source
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: indicatorSlot.glowColor
            shadowBlur: 0.50
            shadowScale: 1.04
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
            shadowOpacity: 1.0
          }

          // Pass 3: Dense saturated core halo hugging the white glyph
          MultiEffect {
            anchors.fill: parent
            visible: indicatorSlot.iconActive
            source: indicatorGlowEffect.source
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: indicatorSlot.glowColor
            shadowBlur: 0.20
            shadowScale: 1.0
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
            shadowOpacity: 1.0
          }
        }
      }

      onLoaded: {
        indicatorSlot.injectProps()
        indicatorSlot.syncActiveState()
      }
      onStatusChanged: if (status === Loader.Error) console.warn("Indicator loader error", indicatorSlot.indicatorId, source)
    }

    Connections {
      target: indicatorSource.item
      ignoreUnknownSignals: true
      function onActiveChanged() { indicatorSlot.syncActiveState() }
    }

    function injectProps() {
      var target = indicatorSource.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("moduleName" in target) target.moduleName = indicatorId
      if ("settings" in target) target.settings = indicatorSettings
      // Glyphs stay pure white; the per-icon aura supplies the colour.
      if ("foreground" in target) target.foreground = "#ffffff"
      if ("indicatorBlock" in target) target.indicatorBlock = indicatorBlock
      if ("indicatorHost" in target) target.indicatorHost = root
      if ("activeOverride" in target) target.activeOverride = indicatorBlock === "active" ? true : null
      // An indicator created before the host injects its block and override
      // can have cached opacity 0 from the provisional state. Re-sync after
      // the props land so an active icon is full strength and a revealed
      // inactive one is dimmed.
      if (typeof target.syncIndicatorOpacity === "function") target.syncIndicatorOpacity()
    }

    function syncActiveState() {
      if (!reportActiveState || !indicatorsModule || !indicatorsModule.setIndicatorActive) return

      var active = !!indicatorSource.item && indicatorSource.item.active === true
      if (indicatorBlock === "active") {
        if (active) activeStateObserved = true
        else if (!activeStateObserved) return
      }

      indicatorsModule.setIndicatorActive(entry, active)
    }
  }
}
