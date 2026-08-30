import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "kiryuuki.oma-kasm"

  readonly property var activeState: panelLoader.item ? panelLoader.item.hubState : null
  readonly property int activeCount: activeState ? (activeState.activeCount || 0) : 0
  readonly property bool serverOnline: activeState ? (activeState.serverOnline === true) : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "kiryuuki.oma-kasm"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰆧"
    foreground: root.opened ? Color.accent : (root.activeCount > 0 ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground))
    slotSize: Style.bar.statusSlot
    tooltipText: root.activeCount > 0 ? ("Kasm Workspaces (" + root.activeCount + " active)") : "Kasm Workspaces"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
