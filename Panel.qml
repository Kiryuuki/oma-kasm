import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "kiryuuki.oma-kasm"
  ipcTarget: "kiryuuki.oma-kasm"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property string activeTab: "workspaces" // "workspaces" | "sessions" | "cluster" | "settings"
  property int selectedIndex: 0
  property string launchingImageId: ""
  property string deletingKasmId: ""
  property var hubState: ({
    serverOnline: false,
    apiAuthenticated: false,
    images: [],
    sessions: [],
    servers: [],
    activeCount: 0
  })

  property var configData: ({
    baseUrl: "https://192.168.100.108",
    apiKey: "",
    apiSecret: "",
    defaultAudio: true,
    defaultMicrophone: false,
    defaultClipboard: true,
    launchMode: "browser"
  })

  // State File Reader
  FileView {
    id: stateFile
    path: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/kasm-hub.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.hubState = JSON.parse(text())
      } catch (e) {}
    }
    onFileChanged: reload()
  }

  // Config File Reader & Writer
  FileView {
    id: configFile
    path: (Quickshell.env("HOME") || "") + "/.config/omarchy/kasm.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.configData = JSON.parse(text())
      } catch (e) {}
    }
    onFileChanged: reload()
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) close(); else open(); }
  function refresh() { syncProcess.running = true }

  onOpenedChanged: {
    if (root.opened) {
      keyCatcher.forceActiveFocus()
      root.selectedIndex = 0
      root.refresh()
    }
  }

  // ------------------ SUBPROCESSES ------------------
  Process {
    id: syncProcess
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-kasm/kasm_engine.py", "--sync"]
    onExited: function(code) { stateFile.reload() }
  }

  property var testResult: null
  property bool isTesting: false
  property bool saveSuccess: false

  Timer {
    id: saveNoticeTimer
    interval: 4000
    onTriggered: root.saveSuccess = false
  }

  Process {
    id: testProcess
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-kasm/kasm_engine.py", "--test"]
    stdout: StdioCollector {
      id: testOut
      waitForEnd: true
      onStreamFinished: {
        root.isTesting = false
        try {
          root.testResult = JSON.parse(testOut.text.trim())
        } catch (e) {
          root.testResult = { ok: false, error: "Invalid response" }
        }
      }
    }
    onExited: function(code) { root.isTesting = false }
  }

  function testConnection(url, key, secret) {
    root.isTesting = true
    root.testResult = null
    var cfg = {
      baseUrl: (url || "").trim(),
      apiKey: (key || "").trim(),
      apiSecret: (secret || "").trim(),
      defaultAudio: root.configData.defaultAudio !== false,
      defaultMicrophone: !!root.configData.defaultMicrophone,
      defaultClipboard: root.configData.defaultClipboard !== false,
      launchMode: "browser"
    }
    configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    testProcess.running = true
  }

  function saveConfig(url, key, secret, audio, mic, clip) {
    root.testResult = null
    var cfg = {
      baseUrl: (url || "").trim(),
      apiKey: (key || "").trim(),
      apiSecret: (secret || "").trim(),
      defaultAudio: audio,
      defaultMicrophone: mic,
      defaultClipboard: clip,
      launchMode: "browser"
    }
    configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    syncProcess.running = true
    root.saveSuccess = true
    saveNoticeTimer.restart()
  }

  // Request Workspace Process
  Process {
    id: requestKasmProcess
    property string targetImageId: ""
    property string directFallbackUrl: ""
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-kasm/kasm_engine.py", "--request-kasm", targetImageId]
    stdout: StdioCollector {
      id: reqOut
      waitForEnd: true
      onStreamFinished: {
        root.launchingImageId = ""
        try {
          var lines = reqOut.text.trim().split("\n")
          var res = null
          for (var i = lines.length - 1; i >= 0; i--) {
            var line = lines[i].trim()
            if (line.startsWith("{") && line.endsWith("}")) {
              try { res = JSON.parse(line); break } catch (e) {}
            }
          }
          if (res && res.kasmUrl) {
            Qt.openUrlExternally(res.kasmUrl)
            root.close()
          } else if (requestKasmProcess.directFallbackUrl) {
            Qt.openUrlExternally(requestKasmProcess.directFallbackUrl)
            root.close()
          }
        } catch (e) {
          if (requestKasmProcess.directFallbackUrl) {
            Qt.openUrlExternally(requestKasmProcess.directFallbackUrl)
            root.close()
          }
        }
      }
    }
    onExited: function(code) { root.launchingImageId = "" }
  }

  function launchWorkspace(imageId, directUrl) {
    // 1. If directUrl is an active session, open it directly without requesting new container
    if (directUrl && directUrl.indexOf("/#/session/") !== -1) {
      Qt.openUrlExternally(directUrl)
      root.close()
      return
    }

    // 2. If credentials are missing, fallback to web portal
    if (!root.configData.apiKey || !root.configData.apiSecret) {
      var target = directUrl || (root.configData.baseUrl + "/#/workspaces")
      Qt.openUrlExternally(target)
      root.close()
      return
    }

    // 3. Otherwise provision new container session
    root.launchingImageId = imageId
    requestKasmProcess.targetImageId = imageId
    requestKasmProcess.directFallbackUrl = directUrl
    requestKasmProcess.running = true
  }

  // Destroy Session Process
  Process {
    id: destroyKasmProcess
    property string targetKasmId: ""
    property string targetUserId: ""
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-kasm/kasm_engine.py", "--destroy-kasm", targetKasmId, "--user-id", targetUserId]
    onExited: function(code) {
      root.deletingKasmId = ""
      syncProcess.running = true
    }
  }

  function destroySession(kasmId, userId) {
    root.deletingKasmId = kasmId
    destroyKasmProcess.targetKasmId = kasmId
    destroyKasmProcess.targetUserId = userId || ""
    destroyKasmProcess.running = true
  }

  // =========================================================================
  // KEYBOARD PANEL
  // =========================================================================
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          var maxIdx = 0
          if (root.activeTab === "workspaces") maxIdx = Math.max(0, (root.hubState.images || []).length - 1)
          else if (root.activeTab === "sessions") maxIdx = Math.max(0, (root.hubState.sessions || []).length - 1)
          root.selectedIndex = Math.max(0, Math.min(maxIdx, root.selectedIndex + dy))
        }
      }
      onActivateRequested: {
        if (root.activeTab === "workspaces") {
          var imgs = root.hubState.images || []
          if (imgs[root.selectedIndex]) {
            root.launchWorkspace(imgs[root.selectedIndex].id, imgs[root.selectedIndex].directUrl || "")
          }
        } else if (root.activeTab === "sessions") {
          var s = root.hubState.sessions || []
          if (s[root.selectedIndex]) {
            Qt.openUrlExternally(s[root.selectedIndex].kasmUrl)
            root.close()
          }
        }
      }
      onDeleteRequested: {
        if (root.activeTab === "sessions") {
          var s = root.hubState.sessions || []
          if (s[root.selectedIndex]) {
            root.destroySession(s[root.selectedIndex].id, s[root.selectedIndex].userId)
          }
        }
      }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "1") { root.activeTab = "workspaces"; root.selectedIndex = 0 }
        else if (t === "2") { root.activeTab = "sessions"; root.selectedIndex = 0 }
        else if (t === "3") { root.activeTab = "cluster"; root.selectedIndex = 0 }
        else if (t === "4" || t === "s" || t === "S") { root.activeTab = "settings"; root.selectedIndex = 0 }
        else if (t === "x" && root.activeTab === "sessions") {
          var s = root.hubState.sessions || []
          if (s[root.selectedIndex]) {
            root.destroySession(s[root.selectedIndex].id, s[root.selectedIndex].userId)
          }
        }
      }

      Flickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: mainColumn.width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: scrollArea.width
          spacing: Style.space(10)

          // ------------------ HEADER ROW ------------------
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Row {
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText
                text: "󰆧"
                color: Color.accent
                font.pixelSize: Style.font.title
              }
              Text {
                textFormat: Text.PlainText
                text: qsTr("Kasm Workspaces")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }

            Item { Layout.fillWidth: true }

            // Status Badge
            BorderSurface {
              implicitHeight: Style.space(24)
              implicitWidth: statusText.implicitWidth + Style.space(16)
              radius: Style.cornerRadius
              color: root.hubState.serverOnline ? Qt.rgba(16/255, 185/255, 129/255, 0.15) : Qt.rgba(239/255, 68/255, 68/255, 0.15)
              borderSpec: Border.controlSpec("normal", root.hubState.serverOnline ? "#10B981" : "#EF4444", Color.accent)

              Text {
                id: statusText
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: root.hubState.serverOnline ? (root.hubState.apiAuthenticated ? qsTr("API Connected") : qsTr("Online")) : qsTr("Offline")
                color: root.hubState.serverOnline ? "#10B981" : "#EF4444"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            // Sync Button
            BorderSurface {
              implicitWidth: Style.space(28)
              implicitHeight: Style.space(28)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(root.contentForeground, root.contentForeground)
              borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.2), Color.accent)

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "󰑐"
                color: root.contentForeground
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh()
              }
            }
          }

          // ------------------ TAB BAR ------------------
          RowLayout {
            width: parent.width
            spacing: Style.space(4)

            readonly property var tabDefs: [
              { key: "workspaces", label: qsTr("Workspaces"), icon: "󰍹", count: (root.hubState.images || []).length },
              { key: "sessions", label: qsTr("Sessions"), icon: "󰄲", count: root.hubState.activeCount || 0 },
              { key: "cluster", label: qsTr("Cluster"), icon: "󰒋", count: (root.hubState.servers || []).length },
              { key: "settings", label: qsTr("Settings"), icon: "󰒓", count: 0 }
            ]

            Repeater {
              model: parent.tabDefs
              delegate: BorderSurface {
                Layout.fillWidth: true
                implicitHeight: Style.space(30)
                radius: Style.cornerRadius
                color: root.activeTab === modelData.key ? Color.accent : Style.hoverFillFor(root.contentForeground, root.contentForeground)
                borderSpec: Border.controlSpec("normal", root.activeTab === modelData.key ? Color.accent : Qt.darker(root.contentForeground, 2.2), Color.accent)

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.icon
                    color: root.activeTab === modelData.key ? "white" : root.contentForeground
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.label + (modelData.count > 0 ? (" (" + modelData.count + ")") : "")
                    color: root.activeTab === modelData.key ? "white" : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: root.activeTab === modelData.key
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.activeTab = modelData.key; root.selectedIndex = 0 }
                }
              }
            }
          }

          // ------------------ TAB CONTENTS ------------------
          WorkspacesView {
            visible: root.activeTab === "workspaces"
            width: parent.width
            workspaces: root.hubState.images || []
            activeSessions: root.hubState.sessions || []
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            selectedIndex: root.activeTab === "workspaces" ? root.selectedIndex : -1
            launchingImageId: root.launchingImageId
            onLaunchRequested: function(id, url) { root.launchWorkspace(id, url) }
          }

          SessionsView {
            visible: root.activeTab === "sessions"
            width: parent.width
            sessions: root.hubState.sessions || []
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            selectedIndex: root.activeTab === "sessions" ? root.selectedIndex : -1
            deletingKasmId: root.deletingKasmId
            onResumeRequested: function(url) { Qt.openUrlExternally(url); root.close() }
            onDestroyRequested: function(id, uid) { root.destroySession(id, uid) }
          }

          ClusterView {
            visible: root.activeTab === "cluster"
            width: parent.width
            servers: root.hubState.servers || []
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          SettingsView {
            visible: root.activeTab === "settings"
            width: parent.width
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            kasmUrl: root.configData.baseUrl || "https://192.168.100.108"
            kasmApiKey: root.configData.apiKey || ""
            kasmApiSecret: root.configData.apiSecret || ""
            enableAudio: root.configData.defaultAudio !== false
            enableMic: !!root.configData.defaultMicrophone
            enableClipboard: root.configData.defaultClipboard !== false
            testResult: root.testResult
            isTesting: root.isTesting
            saveSuccess: root.saveSuccess
            onTestRequested: function(u, k, s) { root.testConnection(u, k, s) }
            onSaveRequested: function(u, k, s, a, m, c) { root.saveConfig(u, k, s, a, m, c) }
          }
        }
      }
    }
  }
}
