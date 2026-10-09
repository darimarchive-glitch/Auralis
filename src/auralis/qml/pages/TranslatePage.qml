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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        Label { text: "Tradutor literário"; font.pixelSize: 28; font.weight: Font.DemiBold }
        Label {
            text: "Tradução local para livros inteiros, com modo literário e cache por capítulo."
            opacity: .65
        }

        RowLayout {
            Layout.fillWidth: true
            ComboBox { id: source; model: ["auto", "en", "es", "fr", "de", "it", "ja", "ko", "zh", "ru", "ar", "hi", "la", "el", "pt"]; currentIndex: 0; Layout.preferredWidth: 140 }
            Label { text: "→"; font.pixelSize: 22 }
            ComboBox { id: target; model: ["pt", "en", "es", "fr", "de", "it", "ja", "ko", "zh", "ru", "ar", "hi"]; Layout.preferredWidth: 140 }
            ComboBox { id: mode; model: ["faithful", "modern", "literal", "study"]; Layout.preferredWidth: 150 }
            CheckBox { id: studio; text: "Refino literário IA" }
            Item { Layout.fillWidth: true }
            Button {
                text: "Traduzir livro selecionado"
                enabled: !controller.busy
                onClicked: controller.translateSelectedBook(target.currentText, source.currentText, mode.currentText, studio.checked)
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            Frame {
                SplitView.preferredWidth: parent.width / 2
                ColumnLayout {
                    anchors.fill: parent
                    Label { text: "Original / texto colado"; font.weight: Font.DemiBold }
                    TextArea { id: sourceText; Layout.fillWidth: true; Layout.fillHeight: true; wrapMode: TextEdit.Wrap; placeholderText: "Cole um trecho aqui ou use um livro da biblioteca…" }
                    Button {
                        text: "Traduzir texto"
                        enabled: sourceText.text.length > 0 && !controller.busy
                        onClicked: controller.translateText(sourceText.text, source.currentText, target.currentText, mode.currentText, studio.checked)
                    }
                }
            }
            Frame {
                SplitView.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    Label { text: "Tradução"; font.weight: Font.DemiBold }
                    TextArea { Layout.fillWidth: true; Layout.fillHeight: true; readOnly: true; wrapMode: TextEdit.Wrap; text: page.translatedText; placeholderText: "A tradução aparece aqui." }
                }
            }
        }
    }
}
