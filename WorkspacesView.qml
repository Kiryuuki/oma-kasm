import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  implicitHeight: contentCol.implicitHeight

  property var workspaces: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int selectedIndex: 0
  property string activeCategory: "All"
  property string searchQuery: ""

  signal launchRequested(string imageId, string directUrl)
  signal searchFocused()

  readonly property var categories: Model.extractCategories(workspaces)
  readonly property var filteredWorkspaces: Model.filterWorkspaces(workspaces, searchQuery, activeCategory)

  Column {
    id: contentCol
    width: parent.width
    spacing: Style.space(8)

    // 1. Search Bar
    BorderSurface {
      width: parent.width
      implicitHeight: Style.space(34)
      radius: Style.cornerRadius
      color: Style.hoverFillFor(root.foreground, root.foreground)
      borderSpec: searchInput.activeFocus ? Border.controlSpec("focus", Color.accent, Color.accent) : Border.controlSpec("normal", Qt.darker(root.foreground, 2.2), Color.accent)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: "󰍉"
          color: searchInput.activeFocus ? Color.accent : Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.bodySmall
        }

        TextInput {
          id: searchInput
          Layout.fillWidth: true
          text: root.searchQuery
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          clip: true

          onTextChanged: root.searchQuery = text

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              if (text.length > 0) {
                text = ""
                event.accepted = true
              } else {
                focus = false
                event.accepted = true
              }
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
              focus = false
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.filteredWorkspaces.length > 0) {
                var target = root.filteredWorkspaces[0]
                root.launchRequested(target.id, target.directUrl || "")
              }
              event.accepted = true
            }
          }
        }

        // Clear Search Button
        Text {
          visible: searchInput.text.length > 0
          textFormat: Text.PlainText
          text: "󰅖"
          color: Qt.darker(root.foreground, 1.8)
          font.pixelSize: Style.font.caption

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { searchInput.text = ""; searchInput.focus = false }
          }
        }
      }
    }

    // 2. Category Filter Pills
    Row {
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: root.categories
        delegate: BorderSurface {
          required property var modelData
          readonly property bool isActive: root.activeCategory === modelData

          implicitHeight: Style.space(24)
          implicitWidth: pillText.implicitWidth + Style.space(16)
          radius: Style.cornerRadius
          color: isActive ? Color.accent : "transparent"
          borderSpec: Border.controlSpec("normal", isActive ? Color.accent : Qt.darker(root.foreground, 2.2), Color.accent)

          Text {
            id: pillText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: parent.modelData
            color: parent.isActive ? "white" : Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: parent.isActive
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activeCategory = parent.modelData
          }
        }
      }
    }

    // 3. Workspaces List
    Column {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: root.filteredWorkspaces
        delegate: BorderSurface {
          id: wsCard
          required property var modelData
          required property int index
          readonly property bool isSelected: root.selectedIndex === index

          width: parent.width
          implicitHeight: cardCol.implicitHeight + Style.space(12)
          radius: Style.cornerRadius
          color: isSelected
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
            : (cardHover.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : Style.hoverFillFor(root.foreground, root.foreground))
          borderSpec: Border.controlSpec(isSelected ? "focus" : "normal", isSelected ? Color.accent : Qt.darker(root.foreground, 2.2), Color.accent)

          HoverHandler { id: cardHover }

          Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(8)
            spacing: Style.space(4)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              // Icon
              BorderSurface {
                implicitWidth: Style.space(32)
                implicitHeight: Style.space(32)
                radius: Style.cornerRadius
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                borderSpec: Border.controlSpec("normal", "transparent", Color.accent)

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: wsCard.modelData.category === "Browsers" ? "󰈹" : (wsCard.modelData.category === "Security" ? "󰌾" : (wsCard.modelData.category === "Development" ? "󰅩" : "󰍹"))
                  color: Color.accent
                  font.pixelSize: Style.font.body
                }
              }

              // Details
              Column {
                Layout.fillWidth: true
                spacing: 2

                Row {
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: wsCard.modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  // Category tag
                  Text {
                    textFormat: Text.PlainText
                    text: wsCard.modelData.category || "Workspace"
                    color: Qt.darker(root.foreground, 1.8)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  text: wsCard.modelData.description || "Interactive container streaming session"
                  color: Qt.darker(root.foreground, 1.6)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Launch Button
              BorderSurface {
                implicitWidth: Style.space(70)
                implicitHeight: Style.space(28)
                radius: Style.cornerRadius
                color: Color.accent
                borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    textFormat: Text.PlainText
                    text: "󰐊"
                    color: "white"
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: qsTr("Launch")
                    color: "white"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchRequested(wsCard.modelData.id, wsCard.modelData.directUrl || "")
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchRequested(wsCard.modelData.id, wsCard.modelData.directUrl || "")
          }
        }
      }

      // Empty State
      Text {
        visible: root.filteredWorkspaces.length === 0
        textFormat: Text.PlainText
        text: qsTr("No workspaces found matching filter")
        color: Qt.darker(root.foreground, 1.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
        topPadding: Style.space(20)
        bottomPadding: Style.space(20)
      }
    }
  }
}
