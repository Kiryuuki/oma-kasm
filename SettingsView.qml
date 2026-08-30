import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root
  implicitHeight: settingsCol.implicitHeight

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  property string kasmUrl: "https://192.168.100.108"
  property string kasmApiKey: ""
  property string kasmApiSecret: ""
  property bool enableAudio: true
  property bool enableMic: false
  property bool enableClipboard: true

  property var testResult: null
  property bool isTesting: false
  property bool saveSuccess: false

  signal testRequested(string url, string key, string secret)
  signal saveRequested(string url, string key, string secret, bool audio, bool mic, bool clip)

  Column {
    id: settingsCol
    width: parent.width
    spacing: Style.space(8)

    // Server URL
    Column {
      width: parent.width
      spacing: 2

      Text {
        textFormat: Text.PlainText
        text: qsTr("Kasm Workspaces Server URL")
        color: Qt.darker(root.foreground, 1.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      BorderSurface {
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: "transparent"
        borderSpec: urlInput.activeFocus ? Border.controlSpec("focus", Color.accent, Color.accent) : Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

        TextInput {
          id: urlInput
          anchors.fill: parent
          anchors.margins: Style.space(6)
          text: root.kasmUrl
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          clip: true
        }
      }
    }

    // API Key
    Column {
      width: parent.width
      spacing: 2

      Text {
        textFormat: Text.PlainText
        text: qsTr("Developer API Key")
        color: Qt.darker(root.foreground, 1.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      BorderSurface {
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: "transparent"
        borderSpec: keyInput.activeFocus ? Border.controlSpec("focus", Color.accent, Color.accent) : Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

        TextInput {
          id: keyInput
          anchors.fill: parent
          anchors.margins: Style.space(6)
          text: root.kasmApiKey
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          clip: true
        }
      }
    }

    // API Secret
    Column {
      width: parent.width
      spacing: 2

      Text {
        textFormat: Text.PlainText
        text: qsTr("Developer API Secret")
        color: Qt.darker(root.foreground, 1.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      BorderSurface {
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: "transparent"
        borderSpec: secretInput.activeFocus ? Border.controlSpec("focus", Color.accent, Color.accent) : Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

        TextInput {
          id: secretInput
          anchors.fill: parent
          anchors.margins: Style.space(6)
          text: root.kasmApiSecret
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          echoMode: TextInput.Password
          selectByMouse: true
          clip: true
        }
      }
    }

    // Session Streaming Defaults
    Text {
      textFormat: Text.PlainText
      text: qsTr("SESSION DEFAULTS")
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      topPadding: Style.space(4)
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(12)

      // Audio Checkbox
      Row {
        spacing: Style.space(4)
        Text {
          textFormat: Text.PlainText
          text: audioToggle.checked ? "󰄲" : "󰄱"
          color: audioToggle.checked ? Color.accent : Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          textFormat: Text.PlainText
          text: qsTr("Audio")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          id: audioToggle
          property bool checked: root.enableAudio
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: checked = !checked
        }
      }

      // Microphone Checkbox
      Row {
        spacing: Style.space(4)
        Text {
          textFormat: Text.PlainText
          text: micToggle.checked ? "󰄲" : "󰄱"
          color: micToggle.checked ? Color.accent : Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          textFormat: Text.PlainText
          text: qsTr("Microphone")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          id: micToggle
          property bool checked: root.enableMic
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: checked = !checked
        }
      }

      // Clipboard Checkbox
      Row {
        spacing: Style.space(4)
        Text {
          textFormat: Text.PlainText
          text: clipToggle.checked ? "󰄲" : "󰄱"
          color: clipToggle.checked ? Color.accent : Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          textFormat: Text.PlainText
          text: qsTr("Clipboard")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          id: clipToggle
          property bool checked: root.enableClipboard
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: checked = !checked
        }
      }
    }

    // Action Buttons Row
    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      // Test Connection Button
      BorderSurface {
        Layout.fillWidth: true
        implicitHeight: Style.space(30)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(root.foreground, root.foreground)
        borderSpec: Border.controlSpec("focus", Color.accent, Color.accent)

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            textFormat: Text.PlainText
            text: root.isTesting ? "" : "󰑐"
            color: Color.accent
            font.pixelSize: Style.font.caption
          }
          Text {
            textFormat: Text.PlainText
            text: root.isTesting ? qsTr("Testing...") : qsTr("Test Connection")
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: !root.isTesting
          cursorShape: Qt.PointingHandCursor
          onClicked: root.testRequested(urlInput.text.trim(), keyInput.text.trim(), secretInput.text.trim())
        }
      }

      // Save & Sync Button
      BorderSurface {
        Layout.fillWidth: true
        implicitHeight: Style.space(30)
        radius: Style.cornerRadius
        color: Color.accent
        borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: qsTr("Save & Sync Now")
          color: "white"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.saveRequested(urlInput.text.trim(), keyInput.text.trim(), secretInput.text.trim(), audioToggle.checked, micToggle.checked, clipToggle.checked)
        }
      }
    }

    // Save Success Banner
    BorderSurface {
      visible: root.saveSuccess
      width: parent.width
      implicitHeight: Style.space(26)
      radius: Style.cornerRadius
      color: Qt.rgba(16/255, 185/255, 129/255, 0.15)
      borderSpec: Border.controlSpec("normal", "#10B981", "#10B981")

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: qsTr("✓ Configuration Saved & Synced Successfully!")
        color: "#10B981"
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    // Test Result Banner
    BorderSurface {
      visible: root.testResult !== null && !root.saveSuccess
      width: parent.width
      implicitHeight: Style.space(26)
      radius: Style.cornerRadius
      color: "transparent"
      borderSpec: Border.controlSpec("normal", root.testResult && root.testResult.ok ? (root.testResult.apiAuthenticated ? "#10B981" : "#F59E0B") : "#EF4444", Color.accent)

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: root.testResult && root.testResult.ok
          ? (root.testResult.message || root.testResult.warning || "✓ Server Online")
          : ("✕ " + (root.testResult ? (root.testResult.error || "Connection Failed") : ""))
        color: root.testResult && root.testResult.ok ? (root.testResult.apiAuthenticated ? "#10B981" : "#F59E0B") : "#EF4444"
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }
}
