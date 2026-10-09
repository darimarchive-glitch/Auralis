import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: page
    property var controller
    signal openReader()
    property string query: ""

    FileDialog {
        id: picker
        title: "Adicionar livro"
        nameFilters: ["Livros (*.epub *.pdf *.txt *.md *.html *.htm *.docx *.fb2 *.rtf)", "Todos os arquivos (*)"]
        onAccepted: controller.importBook(selectedFile.toString())
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: page.width < 600 ? 16 : 26
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Label { text: "Sua biblioteca"; color: "#f6f3ff"; font.pixelSize: page.width < 600 ? 26 : 32; font.weight: Font.DemiBold }
                Label { text: "Abra, escute e traduza sem trocar de aplicativo."; color: "#858294"; visible: page.width > 450 }
            }
            Button { text: "+ Livro"; onClicked: picker.open() }
        }
        TextField {
            Layout.fillWidth: true
            placeholderText: "Buscar na biblioteca"
            leftPadding: 16
            onTextChanged: page.query = text.toLowerCase()
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            GridView {
                id: grid
                cellWidth: page.width < 560 ? (page.width - 32) / 2 : 205
                cellHeight: page.width < 560 ? 280 : 318
                model: controller ? controller.books : []
                delegate: Item {
                    width: grid.cellWidth - 10
                    height: grid.cellHeight - 10
                    visible: page.query.length === 0 || modelData.title.toLowerCase().includes(page.query) || modelData.author.toLowerCase().includes(page.query)
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: mouse.containsMouse ? "#22202d" : "#181720"
                        border.color: mouse.containsMouse ? "#4b4268" : "#272532"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 9
                            Rectangle {
                                width: parent.width
                                height: Math.min(220, grid.cellHeight - 88)
                                radius: 13
                                color: "#292735"
                                clip: true
                                Image { anchors.fill: parent; source: modelData.cover; fillMode: Image.PreserveAspectCrop; visible: modelData.cover.length > 0 }
                                Label { anchors.centerIn: parent; text: "A"; color: "#554e73"; font.pixelSize: 64; visible: modelData.cover.length === 0 }
                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    height: 4; color: "#302e3a"
                                    Rectangle { height: parent.height; width: parent.width * modelData.progress; color: "#8b5cf6" }
                                }
                            }
                            Label { width: parent.width; text: modelData.title; color: "#f0edf8"; elide: Text.ElideRight; font.weight: Font.DemiBold; font.pixelSize: 14 }
                            Label { width: parent.width; text: modelData.author; color: "#8b8898"; elide: Text.ElideRight; font.pixelSize: 12 }
                            Row {
                                spacing: 7
                                Label { text: modelData.progressPercent + "%"; color: "#a78bfa"; font.pixelSize: 11 }
                                Label { text: modelData.translation ? "•  " + modelData.translation.toUpperCase() : "•  " + modelData.format; color: "#6f6c7b"; font.pixelSize: 11 }
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controller.selectBook(modelData.id)
                                page.openReader()
                            }
                        }
                    }
                }
            }
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: controller && controller.books.length === 0
            text: "Adicione seu primeiro EPUB, PDF ou documento."
            color: "#716e7d"
        }
    }
}
