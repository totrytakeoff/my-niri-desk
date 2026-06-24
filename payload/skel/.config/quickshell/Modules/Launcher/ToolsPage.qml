import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root

    signal requestCloseLauncher()

    property int activeTool: -1
    property bool expanded: activeTool >= 0
    property string sourceText: ""
    property string resultText: ""
    property bool translating: false
    property bool dirEnToZh: true
    property var history: []

    function decrementCurrentIndex() {
        if (activeTool >= 0) return
        toolList.decrementCurrentIndex()
    }
    function incrementCurrentIndex() {
        if (activeTool >= 0) return
        toolList.incrementCurrentIndex()
    }
    function forceSearchFocus() {
        if (activeTool >= 0) {
            translateInput.forceActiveFocus()
        } else {
            hiddenInput.forceActiveFocus()
        }
    }

    function selectTool(index) {
        activeTool = index
        if (index === 0) translateInput.forceActiveFocus()
    }

    function activateCurrentTool() {
        if (activeTool >= 0) {
            doTranslate(translateInput.text)
            return
        }
        var idx = toolList.currentIndex
        if (idx >= 0 && idx < toolModel.count && idx === 0) {
            selectTool(idx)
        }
    }

    function handleEscape() {
        if (activeTool >= 0) {
            collapse()
        } else {
            requestCloseLauncher()
        }
    }

    function collapse() {
        activeTool = -1
        hiddenInput.forceActiveFocus()
    }

    function doTranslate(text) {
        var t = (text || translateInput.text).trim()
        if (t.length === 0) return

        sourceText = t
        translating = true
        resultText = ""
        translateProcess.running = false
        var lang = dirEnToZh ? ":zh-CN" : ":en"
        translateProcess.command = ["bash", "-c",
            "trans -no-ansi -no-warn " + lang + " '" + t.replace(/'/g, "'\\''") + "' 2>/dev/null || echo '[translate-shell (trans) not installed. Install: sudo pacman -S translate-shell]'"]
        translateProcess.running = true
    }

    ListModel { id: toolModel }

    Component.onCompleted: {
        toolModel.append({ name: "Translate", icon: "translate", desc: "Multi-language translation via translate-shell" })
        toolModel.append({ name: "More tools", icon: "construction", desc: "Coming soon..." })
        hiddenInput.forceActiveFocus()
    }

    Process {
        id: translateProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                resultText += data + "\n"
            }
        }
        onExited: {
            translating = false
            if (sourceText !== "" && resultText !== "") {
                var h = history.slice()
                h.push({ text: sourceText, result: resultText })
                history = h
            }
        }
    }

    // Hidden input for keyboard focus when in tool list
    TextInput {
        id: hiddenInput
        x: -1000; y: -1000
        width: 0; height: 0
        opacity: 0; visible: true

        Keys.onUpPressed: (event) => { root.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { root.incrementCurrentIndex(); event.accepted = true }
        Keys.onReturnPressed: (event) => { root.activateCurrentTool(); event.accepted = true }
        Keys.onEnterPressed: (event) => { root.activateCurrentTool(); event.accepted = true }
        Keys.onEscapePressed: (event) => {
            root.handleEscape()
            event.accepted = true
        }
    }

    // Tool list view
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        visible: activeTool < 0

        Text {
            text: "Tools"
            color: Colorscheme.on_surface
            font.pixelSize: 18
            font.bold: true
        }

        ListView {
            id: toolList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: toolModel
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: WidgetState.launcherCyclicNavigation
            highlightMoveDuration: 0
            spacing: 8
            currentIndex: 0

            ScrollBar.vertical: ScrollBar {
                width: 6; policy: ScrollBar.AsNeeded; interactive: true
                contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
                background: Rectangle { color: "transparent" }
            }

            highlight: Rectangle {
                color: Colorscheme.primary; radius: 12
            }

            delegate: Item {
                width: ListView.view.width
                height: 64

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        toolList.currentIndex = index
                        root.selectTool(index)
                    }
                    onDoubleClicked: root.selectTool(index)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: ListView.isCurrentItem ? "transparent" : Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.06)
                    border.width: ListView.isCurrentItem ? 0 : 1
                    border.color: Colorscheme.glass_outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 12
                            color: ListView.isCurrentItem ? Qt.rgba(1,1,1,0.2) : Qt.alpha(Colorscheme.primary_container, 0.7)

                            Text {
                                anchors.centerIn: parent
                                text: model.icon
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3

                            Text {
                                text: model.name
                                color: ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                                font.pixelSize: 15; font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.desc
                                color: ListView.isCurrentItem ? Qt.rgba(0,0,0,0.6) : Colorscheme.on_surface_variant
                                font.pixelSize: 11; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "chevron_right"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: ListView.isCurrentItem ? Qt.rgba(0,0,0,0.5) : Colorscheme.on_surface_variant
                        }
                    }
                }
            }
        }
    }

    // Translate tool view
    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        visible: activeTool === 0

        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 8
                color: backMouse.containsMouse ? Colorscheme.surface_variant : "transparent"
                border.width: 1; border.color: Colorscheme.glass_outline

                Text {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Colorscheme.on_surface
                }

                MouseArea {
                    id: backMouse; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.collapse()
                }
            }

            Text {
                text: "Translate"
                color: Colorscheme.on_surface; font.pixelSize: 18; font.bold: true
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 28; radius: 14
                color: dirMouse.containsMouse ? Colorscheme.surface_variant : "transparent"
                border.width: 1; border.color: Colorscheme.glass_outline

                Text {
                    anchors.centerIn: parent
                    text: dirEnToZh ? "EN" : "ZH"
                    font.pixelSize: 12; font.bold: true
                    color: Colorscheme.on_surface
                }

                MouseArea {
                    id: dirMouse; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dirEnToZh = !dirEnToZh
                        if (translateInput.text.trim().length > 0) doTranslate(translateInput.text)
                    }
                }
            }

            Text { text: "→"; color: Colorscheme.on_surface_variant; font.pixelSize: 14 }

            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 28; radius: 14
                color: "transparent"; border.width: 1; border.color: Colorscheme.glass_outline
                Text {
                    anchors.centerIn: parent
                    text: dirEnToZh ? "ZH" : "EN"
                    font.pixelSize: 12; font.bold: true
                    color: Colorscheme.on_surface_variant
                }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
            color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.10)
            border.width: 1; border.color: Colorscheme.glass_outline

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 8

                TextInput {
                    id: translateInput
                    Layout.fillWidth: true
                    color: Colorscheme.on_surface
                    font.pixelSize: 15; clip: true
                    onAccepted: root.doTranslate(translateInput.text)
                }

                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 8
                    color: goMouse.containsMouse ? Colorscheme.primary : Qt.alpha(Colorscheme.primary_container, 0.7)
                    Text {
                        anchors.centerIn: parent
                        text: "arrow_forward"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: goMouse.containsMouse ? Colorscheme.on_primary : Colorscheme.on_primary_container
                    }
                    MouseArea {
                        id: goMouse; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.doTranslate(translateInput.text)
                    }
                }
            }
        }

        Text {
            text: "History:"
            color: Colorscheme.on_surface_variant; font.pixelSize: 12
            visible: history.length > 0
        }

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            visible: history.length > 0
            model: history
            spacing: 6

            ScrollBar.vertical: ScrollBar {
                width: 6; policy: ScrollBar.AsNeeded; interactive: true
                contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
                background: Rectangle { color: "transparent" }
            }

            delegate: Item {
                width: ListView.view.width; height: 44

                Rectangle {
                    anchors.fill: parent; radius: 10
                    color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.06)

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10

                        Text {
                            text: "translate"; font.family: "Material Symbols Rounded"
                            font.pixelSize: 16; color: Colorscheme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            Text {
                                text: modelData.text
                                color: Colorscheme.on_surface; font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    var lines = modelData.result.split("\n")
                                    for (var i = 0; i < lines.length; i++) {
                                        var l = lines[i].trim()
                                        if (l.length > 0 && l.indexOf("/") === -1 && l.indexOf("定义") === -1 && l.indexOf("[") !== 0) {
                                            return l
                                        }
                                    }
                                    return ""
                                }
                                color: Colorscheme.on_surface_variant; font.pixelSize: 11
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                            color: histMouse.containsMouse ? Colorscheme.primary : Qt.alpha(Colorscheme.primary_container, 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "refresh"; font.family: "Material Symbols Rounded"
                                font.pixelSize: 14
                                color: histMouse.containsMouse ? Colorscheme.on_primary : Colorscheme.on_primary_container
                            }
                            MouseArea {
                                id: histMouse; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    translateInput.text = modelData.text
                                    root.doTranslate(modelData.text)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        root.handleEscape()
        event.accepted = true
    }
}
