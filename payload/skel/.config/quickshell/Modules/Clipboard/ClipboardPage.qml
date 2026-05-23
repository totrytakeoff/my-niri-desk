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

    function forceSearchFocus() {
        searchBox.forceActiveFocus()
    }

    function refresh() {
        root.loading = true
        root.errorText = ""
        listProcess.running = false
        listProcess.command = ["desk-run", "clipboard-bridge", "list"]
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
        root.pendingCommand = ["desk-run", "clipboard-bridge", "copy", item.payload]
        root.requestClose()
        actionTimer.restart()
    }

    function pasteSelected() {
        const item = selectedItem()
        if (!item) return
        root.pendingCommand = ["desk-run", "clipboard-bridge", "copy", item.payload]
        root.requestClose()
        actionTimer.restart()
    }

    function transformSelected() {
        const item = selectedItem()
        if (!item || !item.canTransform || !item.transformPayload) {
            copySelected()
            return
        }
        root.pendingCommand = ["desk-run", "clipboard-bridge", "transform-file", item.transformPayload]
        root.requestClose()
        actionTimer.restart()
    }

    function deleteSelected() {
        const item = selectedItem()
        if (!item) return
        actionProcess.running = false
        actionProcess.command = ["desk-run", "clipboard-bridge", "delete", item.raw]
        actionProcess.running = true
    }

    function wipeHistory() {
        actionProcess.running = false
        actionProcess.command = ["desk-run", "clipboard-bridge", "wipe"]
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
    Shortcut { sequence: "Shift+Return"; onActivated: root.transformSelected() }
    Shortcut { sequence: "Shift+Enter"; onActivated: root.transformSelected() }
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
                        onClicked: (mouse) => {
                            root.selectedIndex = index
                            if ((mouse.modifiers & Qt.ShiftModifier) && modelData.canTransform) root.transformSelected()
                            else root.pasteSelected()
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

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            visible: !!modelData.hasExtraMime
                            width: 26
                            height: 26
                            radius: 8
                            color: itemDelegate.ListView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "link"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: itemDelegate.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.primary
                            }
                        }
                    }
                }
            }

            // =========================================================
            // 🎯 【重构版】右侧自适应预览面板（精准治愈排版挤压与溢出）
            // =========================================================
            Rectangle {
                id: previewPanel
                Layout.preferredWidth: 292
                Layout.fillHeight: true
                visible: root.selectedItem() !== null
                radius: 18
                color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.08)
                border.width: 1
                border.color: Colorscheme.glass_outline

                property var currentItem: root.selectedItem()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // --- 1. 顶栏：核心元数据展示 ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 12
                            color: Qt.alpha(Colorscheme.primary_container, 0.76)

                            Text {
                                anchors.centerIn: parent
                                text: root.iconForItem(previewPanel.currentItem)
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 21
                                color: Colorscheme.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: previewPanel.currentItem ? previewPanel.currentItem.summary : "Preview"
                                color: Colorscheme.on_surface
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: previewPanel.currentItem ? root.labelForItem(previewPanel.currentItem) : "Clipboard"
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 12
                                font.family: "JetBrains Mono Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // 附加详细规格描述（如 100.9 KiB | image/jpeg）
                    Text {
                        Layout.fillWidth: true
                        visible: previewPanel.currentItem && previewPanel.currentItem.detailMeta !== ""
                        text: previewPanel.currentItem ? previewPanel.currentItem.detailMeta : ""
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    // --- 2. 核心内容沙盒区（吃掉所有剩余空间，三者互斥显示） ---
                    Item {
                        id: contentSandbox
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // 🟢 【场景 A：图像专属容器】
                        Rectangle {
                            anchors.fill: parent
                            visible: previewPanel.currentItem && previewPanel.currentItem.type === "image" && !!previewPanel.currentItem.previewPath
                            radius: 14
                            color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.10)
                            border.width: 1
                            border.color: Colorscheme.glass_outline
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 8
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: (previewPanel.currentItem && previewPanel.currentItem.previewPath) ? previewPanel.currentItem.previewPath : ""
                            }
                        }

                        // 🟢 【场景 B：纯文本长预览容器】
                        Rectangle {
                            anchors.fill: parent
                            visible: previewPanel.currentItem && previewPanel.currentItem.type !== "image" && previewPanel.currentItem.previewText !== ""
                            radius: 14
                            color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.06)
                            border.width: 1
                            border.color: Colorscheme.glass_outline

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 12
                                clip: true

                                Text {
                                    width: parent.width
                                    text: previewPanel.currentItem ? previewPanel.currentItem.previewText : ""
                                    color: Colorscheme.on_surface
                                    font.pixelSize: 13
                                    font.family: "JetBrains Mono Nerd Font"
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // 🟢 【场景 C：无详细内容时的中央大图标兜底】
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: previewPanel.currentItem && 
                                     !(previewPanel.currentItem.type === "image" && previewPanel.currentItem.previewPath) && 
                                     !(previewPanel.currentItem.type !== "image" && previewPanel.currentItem.previewText !== "")
                            spacing: 12

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.iconForItem(previewPanel.currentItem)
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 48
                                color: Qt.alpha(Colorscheme.primary, 0.5)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: previewPanel.currentItem ? (previewPanel.currentItem.sourcePath || previewPanel.currentItem.subtitle) : ""
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // --- 3. 底栏：微信/QQ 多 MIME 伴生源精致挂件 ---
                    Rectangle {
                        Layout.fillWidth: true
                        visible: !!previewPanel.currentItem && !!previewPanel.currentItem.hasExtraMime
                        Layout.preferredHeight: visible ? extraMimeColumn.implicitHeight + 16 : 0
                        radius: 12
                        color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.15)
                        clip: true

                        ColumnLayout {
                            id: extraMimeColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "link"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Colorscheme.primary
                                }
                                Text {
                                    text: "微信/QQ 伴生元数据"
                                    color: Colorscheme.primary
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Text {
                                visible: !!previewPanel.currentItem && previewPanel.currentItem.associatedPath !== ""
                                text: previewPanel.currentItem ? previewPanel.currentItem.associatedPath : ""
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 11
                                font.family: "JetBrains Mono Nerd Font"
                                elide: Text.ElideMiddle 
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: !!previewPanel.currentItem && !!previewPanel.currentItem.extraMimeType
                                text: previewPanel.currentItem ? ("源头封装格式: " + previewPanel.currentItem.extraMimeType) : ""
                                color: Colorscheme.on_surface_variant
                                font.pixelSize: 10
                            }
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
