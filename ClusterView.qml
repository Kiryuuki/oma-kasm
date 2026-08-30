import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  implicitHeight: clusterCol.implicitHeight

  property var servers: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  Column {
    id: clusterCol
    width: parent.width
    spacing: Style.space(8)

    // Empty state
    BorderSurface {
      visible: (root.servers || []).length === 0
      width: parent.width
      implicitHeight: Style.space(80)
      radius: Style.cornerRadius
      color: Style.hoverFillFor(root.foreground, root.foreground)
      borderSpec: Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

      Column {
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰍹"
          color: Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.title
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("Kasm Agent Server Telemetry")
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("Requires Developer API key with get_servers permission")
          color: Qt.darker(root.foreground, 2.0)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // Servers Repeater
    Repeater {
      model: root.servers
      delegate: BorderSurface {
        id: serverCard
        required property var modelData
        required property int index

        width: parent.width
        implicitHeight: cardCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(root.foreground, root.foreground)
        borderSpec: Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

        Column {
          id: cardCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          RowLayout {
            width: parent.width

            Row {
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText
                text: "󰒋"
                color: Color.accent
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                textFormat: Text.PlainText
                text: serverCard.modelData.hostname
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              textFormat: Text.PlainText
              text: "Zone: " + (serverCard.modelData.zone || "Default")
              color: Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            spacing: Style.space(12)

            Text {
              textFormat: Text.PlainText
              text: "Active Kasms: " + serverCard.modelData.activeKasms + " / " + (serverCard.modelData.maxKasms || "∞")
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              text: Model.formatCores(serverCard.modelData.cores)
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              text: Model.formatMemory(serverCard.modelData.memory)
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
