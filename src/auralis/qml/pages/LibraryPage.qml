import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: page
    property var controller
    FileDialog {
        id: picker
        title: "Adicionar livro"
        nameFilters: ["Livros (*.epub *.pdf *.txt *.md *.html *.htm *.docx *.fb2 *.rtf)", "Todos os arquivos (*)"]
        onAccepted: controller.importBook(selectedFile.toString())
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Label { text: "Sua biblioteca"; font.pixelSize: 28; font.weight: Font.DemiBold }
                Label { text: "Leia, ouça e traduza sem sair do Auralis."; opacity: .65 }
            }
            Button { text: "+ Adicionar livro"; onClicked: picker.open() }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: grid
                cellWidth: 184
                cellHeight: 290
                model: controller ? controller.books : []
                delegate: Item {
                    width: 172; height: 278
                    Column {
                        spacing: 9
                        Rectangle {
                            width: 164; height: 220; radius: 12
                            color: palette.midlight
                            clip: true
                            Image { anchors.fill: parent; source: modelData.cover; fillMode: Image.PreserveAspectCrop; visible: source.toString().length > 0 }
                            Label { anchors.centerIn: parent; text: "A"; font.pixelSize: 60; opacity: .18; visible: modelData.cover.length === 0 }
                            MouseArea { anchors.fill: parent; onClicked: controller.selectBook(modelData.id) }
                        }
                        Label { width: 164; text: modelData.title; elide: Text.ElideRight; font.weight: Font.DemiBold }
                        Label { width: 164; text: modelData.author; elide: Text.ElideRight; opacity: .6; font.pixelSize: 12 }
                        Label { text: modelData.translation ? "Traduzido: " + modelData.translation : modelData.format; opacity: .5; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}
