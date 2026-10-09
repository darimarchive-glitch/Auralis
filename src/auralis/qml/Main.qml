import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Auralis 1.0

ApplicationWindow {
    id: root
    width: 1180
    height: 760
    visible: true
    title: "Auralis"
    color: palette.window

    AppController { id: controller }

    property int pageIndex: 0

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            Label {
                text: "Auralis"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            BusyIndicator { running: controller.busy; visible: running; implicitWidth: 28; implicitHeight: 28 }
            Label { text: controller.status; opacity: .7; visible: text.length > 0 }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: root.width > 760 ? 210 : 74
            Layout.fillHeight: true
            color: palette.alternateBase
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Button { text: root.width > 760 ? "📚  Biblioteca" : "📚"; Layout.fillWidth: true; checked: root.pageIndex === 0; onClicked: root.pageIndex = 0 }
                Button { text: root.width > 760 ? "🌐  Tradutor" : "🌐"; Layout.fillWidth: true; checked: root.pageIndex === 1; onClicked: root.pageIndex = 1 }
                Item { Layout.fillHeight: true }
                Label { text: root.width > 760 ? "Auralis 3.0" : "3.0"; opacity: .5; Layout.alignment: Qt.AlignHCenter }
            }
        }
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.pageIndex
            Loader { source: "pages/LibraryPage.qml"; onLoaded: item.controller = controller }
            Loader { source: "pages/TranslatePage.qml"; onLoaded: item.controller = controller }
        }
    }

    Connections {
        target: controller
        function onErrorOccurred(message) { errorDialog.text = message; errorDialog.open() }
    }
    MessageDialog { id: errorDialog; title: "Auralis" }
}
