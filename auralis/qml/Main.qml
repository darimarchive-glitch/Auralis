import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    width: 1100
    height: 760
    minimumWidth: 390
    minimumHeight: 600
    visible: true
    title: "Auralis"
    color: palette.window

    readonly property color accent: "#3584e4"
    readonly property color surface: palette.windowText.r > 0.5 ? "#252525" : "#ffffff"
    readonly property color surface2: palette.windowText.r > 0.5 ? "#303030" : "#f2f2f2"
    readonly property color muted: palette.windowText.r > 0.5 ? "#b6b6b6" : "#656565"
    readonly property bool reading: backend.currentBook && backend.currentBook.id !== undefined

    SystemPalette { id: systemPalette }
    palette.window: systemPalette.window
    palette.windowText: systemPalette.windowText

    FileDialog {
        id: picker
        title: "Adicionar livro"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Livros (*.pdf *.epub *.txt *.html *.htm *.md *.markdown *.docx *.fb2 *.rtf)", "Todos (*)"]
        onAccepted: backend.importFile(selectedFile.toString())
    }

    Popup {
        id: toast
        width: Math.min(root.width - 32, 560)
        x: (root.width - width) / 2
        y: root.height - height - 28
        padding: 14
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color: "#202020"; radius: 14; opacity: .96 }
        contentItem: Label { id: toastText; color: "white"; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
        Timer { id: toastTimer; interval: 3200; onTriggered: toast.close() }
    }

    Connections {
        target: backend
        function onToast(message) {
            toastText.text = message
            toast.open()
            toastTimer.restart()
        }
    }

    header: ToolBar {
        height: 66
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10
            ToolButton {
                visible: root.reading
                text: "‹"
                font.pixelSize: 30
                onClicked: backend.closeBook()
            }
            Label {
                Layout.fillWidth: true
                text: root.reading ? backend.currentBook.title : "Auralis"
                font.pixelSize: root.reading ? 20 : 27
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            ToolButton { visible: !root.reading; text: "＋"; font.pixelSize: 26; onClicked: picker.open() }
            ToolButton { text: "☰"; font.pixelSize: 20; onClicked: settings.open() }
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.reading ? 1 : 0

        ScrollView {
            id: libraryScroll
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: libraryScroll.availableWidth
                spacing: 22
                topPadding: 24
                bottomPadding: 48
                leftPadding: Math.max(18, (width - 1050) / 2)
                rightPadding: Math.max(18, (width - 1050) / 2)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: backend.books.length ? 190 : 0
                    visible: backend.books.length > 0
                    radius: 24
                    color: root.surface2
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20
                        Rectangle {
                            Layout.preferredWidth: 105
                            Layout.preferredHeight: 150
                            radius: 10
                            color: "#3a3a3a"
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: backend.books.length ? backend.books[0].coverUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: source.toString().length > 0
                            }
                            Label { anchors.centerIn: parent; visible: backend.books.length && !backend.books[0].hasCover; text: "◫"; color: "white"; font.pixelSize: 44 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "CONTINUE OUVINDO"; color: root.accent; font.pixelSize: 12; font.weight: Font.Bold }
                            Label {
                                Layout.fillWidth: true
                                text: backend.books.length ? backend.books[0].title : ""
                                font.pixelSize: 24
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label { text: backend.books.length ? backend.books[0].displayAuthor : ""; color: root.muted }
                            ProgressBar { Layout.fillWidth: true; value: backend.books.length ? backend.books[0].progress : 0 }
                            Button {
                                text: "▶  Continuar"
                                highlighted: true
                                onClicked: if (backend.books.length) backend.openBook(backend.books[0].id)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Sua biblioteca"; font.pixelSize: 24; font.weight: Font.DemiBold }
                    Label { text: backend.books.length + (backend.books.length === 1 ? " livro" : " livros"); color: root.muted }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(2, Math.floor((libraryScroll.availableWidth - 40) / 185))
                    columnSpacing: 18
                    rowSpacing: 24

                    Repeater {
                        model: backend.books
                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 285

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 7
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 140
                                    Layout.preferredHeight: 205
                                    radius: 10
                                    color: root.surface2
                                    clip: true
                                    border.color: palette.mid
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.coverUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: modelData.hasCover
                                    }
                                    Label { anchors.centerIn: parent; visible: !modelData.hasCover; text: "◫"; font.pixelSize: 40; color: root.muted }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) bookMenu.popup()
                                            else backend.openBook(modelData.id)
                                        }
                                    }
                                    Menu {
                                        id: bookMenu
                                        MenuItem { text: "Abrir"; onTriggered: backend.openBook(modelData.id) }
                                        MenuItem { text: "Buscar capa novamente"; onTriggered: backend.refreshMetadata(modelData.id) }
                                        MenuSeparator {}
                                        MenuItem { text: "Remover"; onTriggered: backend.deleteBook(modelData.id) }
                                    }
                                }
                                Label { Layout.fillWidth: true; text: modelData.title; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Label { Layout.fillWidth: true; text: modelData.displayAuthor; color: root.muted; elide: Text.ElideRight; font.pixelSize: 13 }
                                ProgressBar { Layout.fillWidth: true; value: modelData.progress }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: backend.books.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 80
                    spacing: 14
                    Label { Layout.alignment: Qt.AlignHCenter; text: "◫"; font.pixelSize: 64; color: root.muted }
                    Label { Layout.alignment: Qt.AlignHCenter; text: "Sua biblioteca está vazia"; font.pixelSize: 25; font.weight: Font.DemiBold }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 620
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: root.muted
                        text: "Adicione PDF, EPUB, TXT, HTML, Markdown, DOCX, FB2 ou RTF. O Auralis extrai metadados e capas e guarda o livro localmente."
                    }
                    Button { Layout.alignment: Qt.AlignHCenter; text: "＋  Adicionar livro"; highlighted: true; onClicked: picker.open() }
                }
            }
        }

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    color: root.surface2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        ComboBox {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 480
                            model: backend.chapters
                            textRole: "title"
                            onActivated: backend.setChapter(currentIndex)
                        }
                        Label { text: Math.round((backend.currentBook.progress || 0) * 100) + "%"; color: root.muted }
                        ToolButton { text: "⟳"; onClicked: backend.refreshMetadata(backend.currentBook.id) }
                    }
                }

                ListView {
                    id: readerList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: backend.segments
                    currentIndex: backend.currentSegment
                    spacing: 3
                    leftMargin: Math.max(18, (width - 820) / 2)
                    rightMargin: Math.max(18, (width - 820) / 2)
                    topMargin: 30
                    bottomMargin: 130
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Center)

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: readerList.width - readerList.leftMargin - readerList.rightMargin
                        implicitHeight: line.implicitHeight + 20
                        radius: 10
                        color: index === backend.currentSegment ? Qt.rgba(.21,.52,.89,.14) : "transparent"
                        Label {
                            id: line
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            text: modelData.text
                            wrapMode: Text.Wrap
                            lineHeight: 1.34
                            font.pixelSize: modelData.kind === "heading" ? 21 : 18
                            font.weight: modelData.kind === "heading" ? Font.DemiBold : Font.Normal
                        }
                        MouseArea { anchors.fill: parent; onClicked: backend.seekSegment(index) }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 94
                    color: root.surface
                    border.color: palette.mid
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        ToolButton { text: "−15"; onClicked: backend.seekSegment(Math.max(0, backend.currentSegment - 2)) }
                        Button {
                            Layout.preferredWidth: 66
                            Layout.preferredHeight: 56
                            text: backend.playing ? "❚❚" : "▶"
                            highlighted: true
                            font.pixelSize: 21
                            onClicked: backend.toggleNarration()
                        }
                        ToolButton { text: "+15"; onClicked: backend.seekSegment(Math.min(backend.segments.length - 1, backend.currentSegment + 2)) }
                    }
                }
            }
        }
    }

    Drawer {
        id: settings
        edge: Qt.RightEdge
        width: Math.min(root.width * .9, 420)
        height: root.height
        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            ColumnLayout {
                width: settings.width
                padding: 22
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Configurações"; font.pixelSize: 25; font.weight: Font.DemiBold }
                    ToolButton { text: "×"; font.pixelSize: 24; onClicked: settings.close() }
                }
                Label { text: "BIBLIOTECA"; color: root.muted; font.pixelSize: 12; font.weight: Font.Bold }
                Switch { text: "Buscar capas automaticamente"; checked: backend.automaticCovers; onToggled: backend.setAutomaticCovers(checked) }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: root.muted
                    text: "O Auralis prefere a capa incorporada. Se ela não existir, consulta Open Library e Google Books e só aceita resultados com alta confiança."
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }
                Label { text: "NARRAÇÃO"; color: root.muted; font.pixelSize: 12; font.weight: Font.Bold }
                Switch { text: "Preferir voz neural offline"; checked: backend.preferNeural; onToggled: backend.setPreferNeural(checked) }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Velocidade" }
                    Label { text: speed.value.toFixed(2) + "×"; color: root.muted }
                }
                Slider {
                    id: speed
                    Layout.fillWidth: true
                    from: .70
                    to: 1.70
                    stepSize: .05
                    value: backend.narrationRate
                    onMoved: backend.setNarrationRate(value)
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: backend.neuralModelInstalled ? "Supertonic 3 instalado" :
                          (backend.neuralRuntimeAvailable ? "Supertonic 3 disponível para instalar" : "Este build usa a melhor voz do sistema; runtime neural não empacotado.")
                    color: backend.neuralModelInstalled ? "#2ec27e" : root.muted
                }
                Button {
                    visible: backend.neuralRuntimeAvailable && !backend.neuralModelInstalled
                    text: "Baixar voz neural (~150 MB)"
                    onClicked: backend.installNeuralModel()
                }
                ComboBox { Layout.fillWidth: true; model: ["F1","F2","F3","F4","F5","M1","M2","M3","M4","M5"]; onActivated: backend.setVoiceId(currentIndex) }
                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }
                Label { text: "PRIVACIDADE"; color: root.muted; font.pixelSize: 12; font.weight: Font.Bold }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: root.muted
                    text: "Livros, progresso e cache ficam no dispositivo. A internet é opcional e usada somente para capas/metadados e download da voz neural. Sem conta, sem tokens."
                }
                Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.muted; text: "Auralis 3 • Proprietário • Todos os Direitos Reservados" }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: backend.busy
        color: Qt.rgba(0,0,0,.40)
        z: 100
        Column {
            anchors.centerIn: parent
            spacing: 12
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: backend.busy }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: backend.status; color: "white"; font.pixelSize: 16 }
        }
    }
}
