import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTextToSpeech
import "../components"

Item {
    id: page
    property var controller
    property var utteranceStarts: ({})
    property bool autoAdvance: true
    property bool userStopping: false
    property int pendingOffset: 0
    property string currentWord: ""

    function qtRate(value) { return Math.max(-1.0, Math.min(1.0, value - 1.0)) }
    function play() {
        if (!controller || controller.readerText.length === 0) return
        userStopping = false
        speech.stop()
        utteranceStarts = ({})
        let chunks = controller.readerSpeechChunks(controller.readerOffset)
        for (let i = 0; i < chunks.length; i++) {
            let id = speech.enqueue(chunks[i].text)
            utteranceStarts[id] = chunks[i].start
        }
    }
    function stop() { userStopping = true; speech.stop() }
    onVisibleChanged: if (!visible) stop()

    TextToSpeech {
        id: speech
        locale: Qt.locale(controller ? controller.readerLanguage.replace("-", "_") : "pt_BR")
        rate: page.qtRate(controller ? controller.speechRate : 1.0)
        onSayingWord: function(word, id, start, length) {
            page.currentWord = word
            let base = page.utteranceStarts[id]
            if (base === undefined) base = 0
            page.pendingOffset = base + start
            saveProgress.restart()
        }
        onStateChanged: {
            if (state === TextToSpeech.Ready && !page.userStopping && page.autoAdvance && controller && controller.readerChapter < controller.readerChapterCount) {
                controller.nextChapter()
                Qt.callLater(page.play)
            }
        }
    }
    Timer { id: saveProgress; interval: 1000; repeat: false; onTriggered: controller.setReaderOffset(page.pendingOffset) }
    Timer { id: sleepTimer; interval: 30 * 60 * 1000; repeat: false; onTriggered: page.stop() }
    VoiceSheet { id: voiceSheet; parent: Overlay.overlay; tts: speech; controller: page.controller }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: page.width < 600 ? 18 : 32
        spacing: 16
        Item { Layout.fillHeight: true; Layout.minimumHeight: 10 }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(270, page.width * .62)
            Layout.preferredHeight: width * 1.45
            radius: 22; color: "#262432"; clip: true
            Image { anchors.fill: parent; source: controller ? controller.selectedBookCover : ""; fillMode: Image.PreserveAspectCrop; visible: source.toString().length > 0 }
            Label { anchors.centerIn: parent; text: "A"; color: "#554e73"; font.pixelSize: 96; visible: !controller || controller.selectedBookCover.length === 0 }
        }
        Label { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 720; text: controller ? controller.selectedBookTitle : ""; color: "#f5f2fb"; font.pixelSize: 24; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
        Label { Layout.alignment: Qt.AlignHCenter; text: controller ? controller.selectedBookAuthor : ""; color: "#8f8b9d" }
        Label { Layout.alignment: Qt.AlignHCenter; text: controller ? controller.readerChapterTitle : ""; color: "#a78bfa"; font.pixelSize: 13 }
        Label { Layout.alignment: Qt.AlignHCenter; text: page.currentWord.length ? "“" + page.currentWord + "”" : "Pronto para narrar"; color: "#777384"; font.pixelSize: 14 }
        ProgressBar { Layout.fillWidth: true; Layout.maximumWidth: 620; Layout.alignment: Qt.AlignHCenter; from: 0; to: 1; value: controller ? controller.readerProgress : 0 }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 10
            Button { text: "‹"; flat: true; font.pixelSize: 28; onClicked: { page.stop(); controller.previousChapter() } }
            Button {
                text: speech.state === TextToSpeech.Paused ? "▶" : (speech.state === TextToSpeech.Speaking ? "Ⅱ" : "▶")
                font.pixelSize: 28; highlighted: true; Layout.preferredWidth: 76; Layout.preferredHeight: 60
                onClicked: {
                    if (speech.state === TextToSpeech.Speaking) speech.pause()
                    else if (speech.state === TextToSpeech.Paused) speech.resume()
                    else page.play()
                }
            }
            Button { text: "›"; flat: true; font.pixelSize: 28; onClicked: { page.stop(); controller.nextChapter() } }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 8
            Button { text: "Voz • " + (controller ? controller.speechRate.toFixed(2) : "1.00") + "×"; flat: true; onClicked: voiceSheet.open() }
            Button {
                text: sleepTimer.running ? "Timer 30 min ✓" : "Timer 30 min"
                flat: true
                onClicked: sleepTimer.running ? sleepTimer.stop() : sleepTimer.start()
            }
            Switch { text: "Próximo capítulo"; checked: page.autoAdvance; onToggled: page.autoAdvance = checked }
        }
        Label {
            Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 600
            text: controller && controller.readerUseTranslation ? "Narrando a tradução ativa" : "Narrando o texto original"
            color: "#6e6b7a"; font.pixelSize: 12
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: 10 }
    }
}
