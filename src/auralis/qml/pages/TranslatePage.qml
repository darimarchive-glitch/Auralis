import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var controller
    property string translatedText: ""

    Connections {
        target: controller
        function onTranslationReady(text) { page.translatedText = text }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 40
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: content
            width: parent.width
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: page.width < 600 ? 16 : 26
            spacing: 14

            Label { text: "Tradução literária"; color: "#f6f3ff"; font.pixelSize: page.width < 600 ? 26 : 32; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: "Traduza um trecho ou um livro inteiro mantendo diálogos, parágrafos e estilo."; color: "#858294"; wrapMode: Text.Wrap }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 13; color: "#1c1b25"; border.color: "#2a2835"
                Label { anchors.centerIn: parent; text: controller ? controller.translationCapability() : ""; color: "#a69fba"; font.pixelSize: 12 }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: page.width < 720 ? 2 : 5
                columnSpacing: 8; rowSpacing: 8
                ComboBox { id: source; model: ["auto", "en", "es", "fr", "de", "it", "ja", "ko", "zh", "ru", "ar", "hi", "la", "el", "pt"]; currentIndex: 0; Layout.fillWidth: true }
                ComboBox { id: target; model: ["pt", "en", "es", "fr", "de", "it", "ja", "ko", "zh", "ru", "ar", "hi"]; Layout.fillWidth: true }
                ComboBox { id: mode; model: ["faithful", "modern", "literal", "study"]; Layout.fillWidth: true }
                CheckBox { id: studio; text: "Refino IA" }
                Button {
                    text: "Traduzir livro inteiro"
                    enabled: controller && controller.selectedBookId.length > 0 && !controller.busy
                    Layout.fillWidth: true
                    onClicked: controller.translateSelectedBook(target.currentText, source.currentText, mode.currentText, studio.checked)
                }
            }

            Frame {
                Layout.fillWidth: true; Layout.preferredHeight: Math.max(260, page.height * .36)
                background: Rectangle { color: "#181720"; radius: 16; border.color: "#292735" }
                ColumnLayout {
                    anchors.fill: parent
                    Label { text: "Original / texto colado"; color: "#d9d5e4"; font.weight: Font.DemiBold }
                    TextArea { id: sourceText; Layout.fillWidth: true; Layout.fillHeight: true; wrapMode: TextEdit.Wrap; placeholderText: "Cole um trecho aqui…"; color: "#e7e4ed"; background: Item {} }
                    Button {
                        text: "Traduzir texto"
                        highlighted: true
                        enabled: sourceText.text.length > 0 && controller && !controller.busy
                        onClicked: controller.translateText(sourceText.text, source.currentText, target.currentText, mode.currentText, studio.checked)
                    }
                }
            }
            Frame {
                Layout.fillWidth: true; Layout.preferredHeight: Math.max(260, page.height * .36)
                background: Rectangle { color: "#181720"; radius: 16; border.color: "#292735" }
                ColumnLayout {
                    anchors.fill: parent
                    Label { text: "Tradução"; color: "#d9d5e4"; font.weight: Font.DemiBold }
                    TextArea { Layout.fillWidth: true; Layout.fillHeight: true; readOnly: true; wrapMode: TextEdit.Wrap; text: page.translatedText; placeholderText: "A tradução aparece aqui."; color: "#e7e4ed"; background: Item {} }
                }
            }
            Item { Layout.preferredHeight: 18 }
        }
    }
}
