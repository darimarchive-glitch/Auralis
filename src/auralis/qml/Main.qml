import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import Auralis 1.0
import "components"

ApplicationWindow {
    id: root
    width: 1180
    height: 780
    minimumWidth: 360
    minimumHeight: 620
    visible: true
    title: "Auralis"
    color: "#111018"
    Material.theme: Material.Dark
    Material.accent: "#8b5cf6"
    Material.primary: "#171621"

    AppController { id: controller }
    property int pageIndex: controller.selectedBookId.length > 0 ? 1 : 0

    header: Rectangle {
        height: root.width < 600 ? 58 : 66
        color: "#14131c"
        border.color: "#24222e"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            Label {
                text: "Auralis"
                color: "#f6f3ff"
                font.pixelSize: root.width < 600 ? 21 : 24
                font.weight: Font.DemiBold
            }
            Rectangle { width: 1; height: 24; color: "#343241"; visible: root.width >= 640 }
            Label {
                Layout.fillWidth: true
                text: controller.status.length ? controller.status : (controller.selectedBookId.length ? controller.selectedBookTitle : "Sua biblioteca, em qualquer idioma")
                color: controller.status.length ? "#c4b5fd" : "#8f8c9f"
                elide: Text.ElideRight
                visible: root.width >= 520
            }
            BusyIndicator { running: controller.busy; visible: running; implicitWidth: 28; implicitHeight: 28 }
        }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        currentIndex: root.pageIndex
        Loader {
            id: libraryLoader
            source: "pages/LibraryPage.qml"
            onLoaded: {
                item.controller = controller
                item.openReader.connect(function() { root.pageIndex = 1 })
            }
        }
        Loader { source: "pages/ReaderPage.qml"; onLoaded: item.controller = controller }
        Loader { source: "pages/TranslatePage.qml"; onLoaded: item.controller = controller }
        Loader { source: "pages/AudiobookPage.qml"; onLoaded: item.controller = controller }
    }

    footer: Rectangle {
        height: 72
        color: "#15141d"
        border.color: "#292735"
        RowLayout {
            anchors.centerIn: parent
            spacing: root.width < 520 ? 0 : 14
            NavButton { glyph: "▦"; label: "Biblioteca"; selected: root.pageIndex === 0; onClicked: root.pageIndex = 0 }
            NavButton { glyph: "Aa"; label: "Ler"; selected: root.pageIndex === 1; enabled: controller.selectedBookId.length > 0; opacity: enabled ? 1 : .35; onClicked: root.pageIndex = 1 }
            NavButton { glyph: "文"; label: "Traduzir"; selected: root.pageIndex === 2; onClicked: root.pageIndex = 2 }
            NavButton { glyph: "▶"; label: "Audiobook"; selected: root.pageIndex === 3; enabled: controller.selectedBookId.length > 0; opacity: enabled ? 1 : .35; onClicked: root.pageIndex = 3 }
        }
    }

    Connections {
        target: controller
        function onErrorOccurred(message) { errorDialog.text = message; errorDialog.open() }
        function onTranslationReady(text) { if (root.pageIndex !== 2) root.pageIndex = 1 }
    }
    MessageDialog { id: errorDialog; title: "Auralis" }
}
