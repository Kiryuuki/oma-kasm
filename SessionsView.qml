import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root
  implicitHeight: sessionsCol.implicitHeight

  property var sessions: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int selectedIndex: 0
  property string deletingKasmId: ""

  signal resumeRequested(string kasmUrl)
  signal destroyRequested(string kasmId, string userId)

  Column {
    id: sessionsCol
    width: parent.width
    spacing: Style.space(8)

    // Empty state
    BorderSurface {
      visible: (root.sessions || []).length === 0
      width: parent.width
      implicitHeight: Style.space(90)
      radius: Style.cornerRadius
      color: Style.hoverFillFor(root.foreground, root.foreground)
      borderSpec: Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

      Column {
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰌾"
          color: Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.title
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("No active workspace sessions running")
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("Switch to Workspaces (1) to launch a container")
          color: Qt.darker(root.foreground, 2.0)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // Active Sessions Repeater
    Repeater {
      model: root.sessions
      delegate: BorderSurface {
        id: sessionCard
        required property var modelData
        required property int index
        readonly property bool isSelected: root.selectedIndex === index

        width: parent.width
        implicitHeight: cardRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: isSelected
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          : Style.hoverFillFor(root.foreground, root.foreground)
        borderSpec: Border.controlSpec(isSelected ? "focus" : "normal", isSelected ? Color.accent : Qt.darker(root.foreground, 2.2), Color.accent)

        RowLayout {
          id: cardRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(8)

          // Status Dot
          Rectangle {
            implicitWidth: Style.space(10)
            implicitHeight: Style.space(10)
            radius: width / 2
            color: sessionCard.modelData.status === "running" ? "#10B981" : "#F59E0B"
          }

          // Session Details
          Column {
            Layout.fillWidth: true
            spacing: 2

            Row {
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText
                text: sessionCard.modelData.imageName || qsTr("Workspace Session")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              // Persistent Profile indicator badge
              BorderSurface {
                visible: !!sessionCard.modelData.hasPersistentProfile
                implicitHeight: Style.space(16)
                implicitWidth: sProfText.implicitWidth + Style.space(8)
                radius: Style.cornerRadius
                color: Qt.rgba(168/255, 85/255, 247/255, 0.15)
                borderSpec: Border.controlSpec("normal", "#A855F7", "#A855F7")

                Text {
                  id: sProfText
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: "󰋊 " + qsTr("Profile")
                  color: "#A855F7"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.micro || 9
                  font.bold: true
                }
              }

              Text {
                textFormat: Text.PlainText
                text: sessionCard.modelData.status || "running"
                color: sessionCard.modelData.status === "running" ? "#10B981" : "#F59E0B"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Text {
              textFormat: Text.PlainText
              text: (sessionCard.modelData.username ? ("User: " + sessionCard.modelData.username) : "") + (sessionCard.modelData.serverHostname ? (" · Node: " + sessionCard.modelData.serverHostname) : "")
              color: Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Resume Button
          BorderSurface {
            implicitWidth: Style.space(70)
            implicitHeight: Style.space(28)
            radius: Style.cornerRadius
            color: Color.accent
            borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: qsTr("Resume")
              color: "white"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.resumeRequested(sessionCard.modelData.kasmUrl)
            }
          }

          // Destroy / Terminate Button
          BorderSurface {
            readonly property bool isDeletingThis: root.deletingKasmId !== "" && root.deletingKasmId === sessionCard.modelData.id
            implicitWidth: Style.space(28)
            implicitHeight: Style.space(28)
            radius: Style.cornerRadius
            color: isDeletingThis ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : "transparent"
            borderSpec: Border.controlSpec("normal", "#EF4444", Color.accent)

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: parent.isDeletingThis ? "" : "󰆴"
              color: "#EF4444"
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              enabled: !parent.isDeletingThis
              cursorShape: parent.isDeletingThis ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: root.destroyRequested(sessionCard.modelData.id, sessionCard.modelData.userId || "")
            }
          }
        }
      }
    }
  }
}
