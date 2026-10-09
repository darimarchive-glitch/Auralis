import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTextToSpeech
import "../components"

Item {
    id: page
    property var controller
    property var utteranceStarts: ({})
    property var utteranceLengths: ({})
    property int pendingOffset: 0
    property bool queueActive: false

    function qtRate(value) { return Math.max(-1.0, Math.min(1.0, value - 1.0)) }

    function startNarration() {
        if (!controller || controller.readerText.length === 0) return
        speech.stop()
        utteranceStarts = ({})
        utteranceLengths = ({})
        let chunks = controller.readerSpeechChunks(controller.readerOffset)
        if (!chunks.length) return
        queueActive = true
        for (let i = 0; i < chunks.length; i++) {
            let id = speech.enqueue(chunks[i].text)
            utteranceStarts[id] = chunks[i].start
            utteranceLengths[id] = chunks[i].length
        }
    }

    function stopNarration() {
        queueActive = false
        speech.stop()
    }

    onVisibleChanged: if (!visible) stopNarration()

    TextToSpeech {
        id: speech
        locale: Qt.locale(controller ? controller.readerLanguage.replace("-", "_") : "pt_BR")
        rate: page.qtRate(controller ? controller.speechRate : 1.0)
        onAboutToSynthesize: function(id) {
            let base = page.utteranceStarts[id]
            let len = page.utteranceLengths[id]
            if (base !== undefined && len !== undefined) {
                reader.select(base, Math.min(reader.length, base + len))
            }
        }
        onSayingWord: function(word, id, start, length) {
            let base = page.utteranceStarts[id]
            if (base === undefined) base = 0
            let absoluteStart = base + start
            reader.select(absoluteStart, Math.min(reader.length, absoluteStart + length))
            page.pendingOffset = absoluteStart
            saveProgress.restart()
        }
        onStateChanged: {
            if (state === TextToSpeech.Ready) page.queueActive = false
        }
    }

    Timer {
        id: saveProgress
        interval: 900
        repeat: false
        onTriggered: if (controller) controller.setReaderOffset(page.pendingOffset)
    }

    VoiceSheet { id: voiceSheet; parent: Overlay.overlay; tts: speech; controller: page.controller }

    Popup {
        id: bookSheet
        parent: Overlay.overlay
        modal: true
        width: parent ? parent.width : 600
        height: Math.min(parent ? parent.height * .65 : 480, 520)
        x: 0; y: parent ? parent.height - height : 0
        padding: 0
        background: Rectangle { color: "#191821"; radius: 26; border.color: "#302e3d" }
        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Trocar de livro"; color: "#f5f3ff"; font.pixelSize: 22; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Button { text: "Fechar"; flat: true; onClicked: bookSheet.close() }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 8
                model: controller ? controller.books : []
                delegate: Rectangle {
                    width: ListView.view.width; height: 66; radius: 14
                    color: modelData.id === controller.selectedBookId ? "#2f2752" : mouse.containsMouse ? "#24222f" : "#1f1e29"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 9; spacing: 12
                        Rectangle {
                            width: 38; height: 50; radius: 6; color: "#322f40"; clip: true
                            Image { anchors.fill: parent; source: modelData.cover; fillMode: Image.PreserveAspectCrop; visible: modelData.cover.length > 0 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: modelData.title; color: "#f0edf8"; elide: Text.ElideRight; Layout.fillWidth: true }
                            Label { text: modelData.author; color: "#858293"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Label { text: modelData.progressPercent + "%"; color: "#a78bfa" }
                    }
                    MouseArea {
                        id: mouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: { page.stopNarration(); controller.selectBook(modelData.id); bookSheet.close() }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#12111a"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                Button { text: "‹"; flat: true; font.pixelSize: 26; onClicked: { page.stopNarration(); controller.previousChapter() } }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Label { text: controller ? controller.readerChapterTitle : ""; color: "#f2eff8"; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                    Label { text: controller ? "Capítulo " + controller.readerChapter + " de " + controller.readerChapterCount : ""; color: "#777485"; font.pixelSize: 11 }
                }
                Button {
                    visible: controller && controller.readerTranslationAvailable
                    text: controller && controller.readerUseTranslation ? "Traduzido" : "Original"
                    highlighted: controller && controller.readerUseTranslation
                    onClicked: { page.stopNarration(); controller.setReaderUseTranslation(!controller.readerUseTranslation) }
                }
                Button { text: "›"; flat: true; font.pixelSize: 26; onClicked: { page.stopNarration(); controller.nextChapter() } }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: "#111018"
            TextArea {
                id: reader
                anchors.fill: parent
                anchors.leftMargin: page.width < 650 ? 15 : Math.max(48, (page.width - 760) / 2)
                anchors.rightMargin: page.width < 650 ? 15 : Math.max(48, (page.width - 760) / 2)
                anchors.topMargin: 18; anchors.bottomMargin: 18
                text: controller ? controller.readerText : ""
                readOnly: true
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: "#e8e5ed"
                selectionColor: "#57479a"
                selectedTextColor: "#ffffff"
                font.pixelSize: page.width < 600 ? 19 : 20
                font.family: "Noto Serif"
                lineHeight: 1.48
                lineHeightMode: Text.ProportionalHeight
                background: Item {}
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: page.width < 600 ? 86 : 76
            color: "#181721"
            border.color: "#2b2936"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 5
                Button { text: "▦\nLivro"; flat: true; onClicked: bookSheet.open() }
                Button { text: "−"; flat: true; onClicked: { page.stopNarration(); controller.previousChapter() } }
                Button {
                    Layout.preferredWidth: 70; Layout.preferredHeight: 56
                    text: speech.state === TextToSpeech.Paused ? "▶" : (speech.state === TextToSpeech.Speaking ? "Ⅱ" : "▶")
                    font.pixelSize: 25
                    highlighted: true
                    onClicked: {
                        if (speech.state === TextToSpeech.Speaking) speech.pause()
                        else if (speech.state === TextToSpeech.Paused) speech.resume()
                        else page.startNarration()
                    }
                }
                Button { text: "+"; flat: true; onClicked: { page.stopNarration(); controller.nextChapter() } }
                Item { Layout.fillWidth: true }
                Button { text: (controller ? controller.speechRate.toFixed(2) : "1.00") + "×"; flat: true; onClicked: voiceSheet.open() }
                Button { text: "Voz"; flat: true; onClicked: voiceSheet.open() }
            }
        }
    }
}
