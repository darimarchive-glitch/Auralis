import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string glyph: "●"
    property string label: "Item"
    property bool selected: false
    signal clicked()
    implicitWidth: 92
    implicitHeight: 62

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 8, 78)
        height: 48
        radius: 18
        color: root.selected ? "#2f2752" : mouse.containsMouse ? "#242331" : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Column {
            anchors.centerIn: parent
            spacing: 1
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.glyph
                font.pixelSize: 19
                color: root.selected ? "#c4b5fd" : "#b8b6c8"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                font.pixelSize: 10
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                color: root.selected ? "#e9e4ff" : "#aaa8b8"
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
