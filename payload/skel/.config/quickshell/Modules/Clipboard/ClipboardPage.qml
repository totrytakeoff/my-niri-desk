import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root

    signal requestClose()

    property var allItems: []
    property var filteredItems: []
    property string errorText: ""
    property bool loading: false
    property int selectedIndex: 0
    property var pendingCommand: []
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_bridge.py"

    function forceSearchFocus() {
        searchBox.forceActiveFocus()
    }

    function refresh() {
        root.loading = true
        root.errorText = ""
        listProcess.running = false
        listProcess.command = ["python3", root.scriptPath, "list"]
        listProcess.running = true
    }

    function iconForType(type) {
        if (type === "image") return "image"
        if (type === "link") return "link"
        if (type === "file") return "draft"
        return "content_paste"
    }

    function iconForItem(item) {
        if (!item) return "content_paste"
        if (item.type === "file") {
            if (item.fileKind === "folder") return "folder"
            if (item.fileKind === "text-file") return "description"
            if (item.fileKind === "pdf") return "picture_as_pdf"
            if (item.fileKind === "video") return "movie"
            if (item.fileKind === "audio") return "audio_file"
        }
        return root.iconForType(item.type)
    }

    function labelForType(type) {
        if (type === "image") return "Image"
        if (type === "link") return "Link"
        if (type === "file") return "File"
        return "Text"
    }

    function labelForItem(item) {
        if (!item) return "Clipboard"
        if (item.type === "file") {
            if (item.fileKind === "folder") return "Folder"
            if (item.fileKind === "text-file") return "Text File"
            if (item.fileKind === "pdf") return "PDF"
            if (item.fileKind === "video") return "Video"
            if (item.fileKind === "audio") return "Audio"
        }
        return root.labelForType(item.type)
    }

    function typeRank(type) {
        if (type === "text") return 0
        if (type === "image") return 1
        if (type === "link") return 2
        if (type === "file") return 3
        return 4
    }

    function filterItems() {
        const query = searchBox.text.trim().toLowerCase()
        const next = []
        for (let i = 0; i < root.allItems.length; i++) {
            const item = root.allItems[i]
            const haystack = ((item.summary || "") + " " + (item.type || "")).toLowerCase()
            if (query === "" || haystack.indexOf(query) !== -1) next.push(item)
        }
        root.filteredItems = next
        if (root.selectedIndex >= next.length) root.selectedIndex = Math.max(0, next.length - 1)
        if (itemsList.currentIndex !== root.selectedIndex) itemsList.currentIndex = root.selectedIndex
    }

    function clampIndex() {
        if (root.filteredItems.length === 0) {
            root.selectedIndex = 0
            itemsList.currentIndex = -1
            return
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.filteredItems.length - 1))
        itemsList.currentIndex = root.selectedIndex
    }

    function moveSelection(delta) {
        if (root.filteredItems.length === 0) return
        const count = root.filteredItems.length
        root.selectedIndex = (root.selectedIndex + delta + count) % count
        itemsList.currentIndex = root.selectedIndex
        itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    function selectedItem() {
        if (root.filteredItems.length === 0) return null
        return root.filteredItems[root.selectedIndex]
    }

    function copySelected() {
        const item = selectedItem()
        if (!item) return
        root.pendingCommand = ["python3", root.scriptPath, "copy", item.payload]
        root.requestClose()
        actionTimer.restart()
    }

    function pasteSelected() {
        const item = selectedItem()
        if (!item) return
        root.pendingCommand = ["python3", root.scriptPath, "copy", item.payload]
        root.requestClose()
        actionTimer.restart()
    }

    function deleteSelected() {
        const item = selectedItem()
        if (!item) return
        actionProcess.running = false
        actionProcess.command = ["python3", root.scriptPath, "delete", item.raw]
        actionProcess.running = true
    }

    function wipeHistory() {
        actionProcess.running = false
        actionProcess.command = ["python3", root.scriptPath, "wipe"]
        actionProcess.running = true
    }

    Process {
        id: listProcess
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const parsed = JSON.parse(data.trim())
                    root.loading = false
                    root.errorText = parsed.ok ? "" : (parsed.error || "cliphist failed")
                    root.allItems = parsed.items || []
                    root.selectedIndex = 0
                    root.filterItems()
                } catch (e) {
                    root.loading = false
                    root.errorText = "Cannot parse cliphist output"
                    root.allItems = []
                    root.filterItems()
                }
            }
        }
        onExited: (code) => {
            root.loading = false
            if (code !== 0 && root.errorText === "") root.errorText = "cliphist command failed"
        }
    }

    Process {
        id: actionProcess
        onExited: root.refresh()
    }

    Timer {
        id: actionTimer
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.pendingCommand || root.pendingCommand.length === 0) return
            actionProcess.running = false
            actionProcess.command = root.pendingCommand
            root.pendingCommand = []
            actionProcess.running = true
        }
    }

    Shortcut { sequence: "Escape"; onActivated: root.requestClose() }
    Shortcut { sequence: "Up"; onActivated: root.moveSelection(-1) }
    Shortcut { sequence: "Down"; onActivated: root.moveSelection(1) }
    Shortcut { sequence: "Return"; onActivated: root.copySelected() }
    Shortcut { sequence: "Enter"; onActivated: root.copySelected() }
    Shortcut { sequence: "Ctrl+Return"; onActivated: root.copySelected() }
    Shortcut { sequence: "Ctrl+Enter"; onActivated: root.copySelected() }
    Shortcut { sequence: "Delete"; onActivated: root.deleteSelected() }
    Shortcut { sequence: "Ctrl+Delete"; onActivated: root.wipeHistory() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 14
                color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.10)
                border.width: 1
                border.color: Qt.alpha(Colorscheme.inverse_surface, 0.18)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "search"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 21
                        color: Colorscheme.on_surface_variant
                    }

                    TextInput {
                        id: searchBox
                        Layout.fillWidth: true
                        color: Colorscheme.on_surface
                        selectionColor: Colorscheme.primary
                        selectedTextColor: Colorscheme.on_primary
                        font.pixelSize: 16
                        clip: true
                        focus: true
                        onTextChanged: root.filterItems()
                        Keys.onUpPressed: (event) => { root.moveSelection(-1); event.accepted = true }
                        Keys.onDownPressed: (event) => { root.moveSelection(1); event.accepted = true }
                        Keys.onReturnPressed: (event) => { root.copySelected(); event.accepted = true }
                        Keys.onEnterPressed: (event) => { root.copySelected(); event.accepted = true }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 14
                color: refreshMouse.containsMouse ? Colorscheme.surface_variant : "transparent"
                border.width: 1
                border.color: Colorscheme.glass_outline

                Text {
                    anchors.centerIn: parent
                    text: "refresh"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Colorscheme.on_surface
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 170
                Layout.fillHeight: true
                radius: 18
                color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.08)
                border.width: 1
                border.color: Colorscheme.glass_outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Text {
                        text: root.filteredItems.length + " Items"
                        color: Colorscheme.on_surface
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: root.errorText !== "" ? root.errorText : "Enter copies"
                        color: root.errorText !== "" ? Colorscheme.error : Colorscheme.on_surface_variant
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Colorscheme.glass_outline
                    }

                    Repeater {
                        model: [
                            { type: "text", label: "Text" },
                            { type: "image", label: "Image" },
                            { type: "link", label: "Link" },
                            { type: "file", label: "File" }
                        ]

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: root.iconForType(modelData.type)
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: Colorscheme.primary
                            }
                            Text {
                                text: modelData.label
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Text {
                                text: {
                                    let count = 0
                                    for (let i = 0; i < root.allItems.length; i++) {
                                        if (root.allItems[i].type === modelData.type) count++
                                    }
                                    return String(count)
                                }
                                color: Colorscheme.on_surface
                                font.pixelSize: 12
                                font.family: "JetBrains Mono Nerd Font"
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "Ctrl+Delete clears history"
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }

            ListView {
                id: itemsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 520
                clip: true
                model: root.filteredItems
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: WidgetState.launcherCyclicNavigation
                highlightMoveDuration: 0
                spacing: 8

                highlight: Rectangle {
                    color: Colorscheme.primary
                    radius: 14
                }

                delegate: Item {
                    id: itemDelegate
                    width: ListView.view.width
                    height: 72

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedIndex = index
                            itemsList.currentIndex = index
                        }
                        onClicked: {
                            root.selectedIndex = index
                            root.pasteSelected()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 12
                            color: itemDelegate.ListView.isCurrentItem ? Colorscheme.on_primary : Qt.alpha(Colorscheme.primary_container, 0.70)
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: modelData.previewPath || ""
                                visible: source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.iconForItem(modelData)
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 21
                                color: itemDelegate.ListView.isCurrentItem ? Colorscheme.primary : Colorscheme.on_primary_container
                                visible: !parent.children[0].visible
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: modelData.summary
                                color: itemDelegate.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                                font.pixelSize: 15
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.subtitle || (root.labelForType(modelData.type) + (modelData.id !== "" ? " #" + modelData.id : ""))
                                color: itemDelegate.ListView.isCurrentItem ? Qt.rgba(0, 0, 0, 0.62) : Colorscheme.on_surface_variant
                                font.pixelSize: 12
                                font.family: "JetBrains Mono Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 292
                Layout.fillHeight: true
                visible: root.selectedItem() !== null
                radius: 18
                color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.08)
                border.width: 1
                border.color: Colorscheme.glass_outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 12
                            color: Qt.alpha(Colorscheme.primary_container, 0.76)

                            Text {
                                anchors.centerIn: parent
                                text: root.iconForItem(root.selectedItem())
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 21
                                color: Colorscheme.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.selectedItem() ? root.selectedItem().summary : "Preview"
                                color: Colorscheme.on_surface
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.selectedItem() ? root.labelForItem(root.selectedItem()) : "Clipboard"
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 12
                                font.family: "JetBrains Mono Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.selectedItem() && root.selectedItem().detailMeta !== ""
                        text: root.selectedItem() ? root.selectedItem().detailMeta : ""
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.selectedItem() && root.selectedItem().previewPath ? 220 : 0
                        visible: root.selectedItem() && root.selectedItem().previewPath
                        radius: 16
                        color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.10)
                        border.width: 1
                        border.color: Colorscheme.glass_outline
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            source: root.selectedItem() ? root.selectedItem().previewPath : ""
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16
                        color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.06)
                        border.width: 1
                        border.color: Colorscheme.glass_outline

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 12
                            clip: true
                            visible: root.selectedItem() && root.selectedItem().previewText !== ""

                            Text {
                                width: parent.width
                                text: root.selectedItem() ? root.selectedItem().previewText : ""
                                color: Colorscheme.on_surface
                                font.pixelSize: 13
                                font.family: "JetBrains Mono Nerd Font"
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            visible: !root.selectedItem() || root.selectedItem().previewText === ""
                            spacing: 8

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.iconForItem(root.selectedItem())
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 42
                                color: Colorscheme.primary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.selectedItem() ? (root.selectedItem().sourcePath || root.selectedItem().subtitle) : "Select an item"
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.loading ? "Loading clipboard history..." : "No clipboard history"
        color: Colorscheme.on_surface_variant
        font.pixelSize: 16
        visible: root.filteredItems.length === 0 && root.errorText === "" && root.selectedItem() === null
    }
}
