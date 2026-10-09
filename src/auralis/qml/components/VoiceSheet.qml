import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    property var tts
    property var controller
    property var voiceRows: []
    property int selectedIndex: -1
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: parent ? parent.width : 680
    height: Math.min(parent ? parent.height * 0.58 : 430, 460)
    x: 0
    y: parent ? parent.height - height : 0
    padding: 0

    background: Rectangle {
        color: "#191821"
        radius: 26
        border.color: "#302e3d"
        border.width: 1
    }

    function score(name) {
        let n = (name || "").toLowerCase()
        let s = 0
        if (n.includes("natural") || n.includes("neural")) s += 50
        if (n.includes("premium") || n.includes("enhanced")) s += 35
        if (n.includes("google")) s += 20
        if (n.includes("online")) s += 10
        return s
    }

    function refresh() {
        if (!root.tts) return
        let source = root.tts.availableVoices()
        let rows = []
        for (let i = 0; i < source.length; i++) {
            let voice = source[i]
            let localeName = voice.locale ? voice.locale.name : ""
            rows.push({
                "label": voice.name + (localeName ? "  •  " + localeName.replace("_", "-") : ""),
                "name": voice.name,
                "voice": voice,
                "score": root.score(voice.name)
            })
        }
        rows.sort(function(a, b) { return b.score - a.score || a.label.localeCompare(b.label) })
        root.voiceRows = rows
        root.selectedIndex = -1
        if (root.controller && root.controller.preferredVoice) {
            for (let j = 0; j < rows.length; j++) {
                if (rows[j].name === root.controller.preferredVoice) {
                    root.selectedIndex = j
                    root.tts.voice = rows[j].voice
                    break
                }
            }
        }
        if (root.selectedIndex < 0 && rows.length > 0) {
            root.selectedIndex = 0
            root.tts.voice = rows[0].voice
        }
    }

    onOpened: refresh()

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Label { text: "Voz da narração"; font.pixelSize: 22; font.weight: Font.DemiBold; color: "#f5f3ff" }
                Label { text: "As vozes mais naturais aparecem primeiro quando o sistema informa a qualidade."; color: "#9f9cae"; wrapMode: Text.Wrap }
            }
            Button { text: "Fechar"; flat: true; onClicked: root.close() }
        }
        Frame {
            Layout.fillWidth: true
            background: Rectangle { color: "#22212c"; radius: 16 }
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                Label { text: root.tts ? "Mecanismo: " + root.tts.engine : ""; color: "#8f8ca0"; font.pixelSize: 12 }
                ComboBox {
                    id: voiceCombo
                    Layout.fillWidth: true
                    model: root.voiceRows
                    textRole: "label"
                    currentIndex: root.selectedIndex
                    onActivated: {
                        if (currentIndex >= 0 && currentIndex < root.voiceRows.length) {
                            root.tts.voice = root.voiceRows[currentIndex].voice
                            root.controller.setPreferredVoice(root.voiceRows[currentIndex].name)
                            root.selectedIndex = currentIndex
                        }
                    }
                }
            }
        }
        Label { text: "Velocidade"; color: "#c9c6d6"; font.weight: Font.Medium }
        RowLayout {
            Layout.fillWidth: true
            Slider {
                id: speed
                Layout.fillWidth: true
                from: 0.6; to: 2.0; stepSize: 0.05
                value: root.controller ? root.controller.speechRate : 1.0
                onMoved: root.controller.setSpeechRate(value)
            }
            Label { text: speed.value.toFixed(2) + "×"; color: "#c4b5fd"; Layout.preferredWidth: 52 }
        }
        Label {
            Layout.fillWidth: true
            text: "No Android, o Auralis usa as vozes instaladas no mecanismo de fala do aparelho. Vozes Google/Natural/Premium instaladas aparecem aqui automaticamente."
            color: "#777486"; wrapMode: Text.Wrap; font.pixelSize: 12
        }
        Item { Layout.fillHeight: true }
    }
}
