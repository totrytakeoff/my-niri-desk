import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root

    signal requestCloseLauncher()

    property bool searching: false
    readonly property bool gridMode: WidgetState.launcherLayoutMode === "grid"

    ListModel { id: fileModel }

    function normalizedIndex(index, count) {
        if (count <= 0) return -1
        if (WidgetState.launcherCyclicNavigation) return (index % count + count) % count
        return Math.max(0, Math.min(index, count - 1))
    }

    function selectIndex(index) {
        if (fileModel.count === 0) return
        var idx = normalizedIndex(index, fileModel.count)
        fileList.currentIndex = idx
        fileGrid.currentIndex = idx
        if (root.gridMode) fileGrid.positionViewAtIndex(idx, GridView.Contain)
        else fileList.positionViewAtIndex(idx, ListView.Contain)
    }

    function gridColumns() {
        return Math.max(1, Math.floor(fileGrid.width / fileGrid.cellWidth))
    }

    function moveGrid(delta) {
        selectIndex(fileGrid.currentIndex + delta)
    }

    function decrementCurrentIndex() {
        if (gridMode) moveGrid(-gridColumns())
        else selectIndex(fileList.currentIndex - 1)
    }
    function incrementCurrentIndex() {
        if (gridMode) moveGrid(gridColumns())
        else selectIndex(fileList.currentIndex + 1)
    }
    function forceSearchFocus() { searchBox.forceActiveFocus() }

    function doSearch(text) {
        fileModel.clear()
        var q = text.trim()
        if (q.length < 2) return
        searching = true
        searchProcess.running = false
        searchProcess.command = ["bash", "-c",
            "find $HOME -maxdepth 5 -type f -iname '*" + q.replace(/'/g, "'\\''") + "*' -not -path '*/.*' 2>/dev/null | head -60"]
        searchProcess.running = true
    }

    function openSelected() {
        var idx = root.gridMode ? fileGrid.currentIndex : fileList.currentIndex
        if (fileModel.count === 0 || idx < 0) return
        var path = fileModel.get(idx).path
        Quickshell.execDetached(["xdg-open", path])
        root.requestCloseLauncher()
    }

    function openWithVSCode() {
        var idx = root.gridMode ? fileGrid.currentIndex : fileList.currentIndex
        if (fileModel.count === 0 || idx < 0) return
        var path = fileModel.get(idx).path
        Quickshell.execDetached(["code", path])
        root.requestCloseLauncher()
    }

    TextInput {
        id: searchBox
        x: -1000; y: -1000
        width: 0; height: 0
        opacity: 0; visible: true

        onTextChanged: root.doSearch(text)
        Keys.onReturnPressed: (event) => { openSelected(); event.accepted = true }
        Keys.onEnterPressed: (event) => { openSelected(); event.accepted = true }
        Keys.onUpPressed: (event) => { root.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { root.incrementCurrentIndex(); event.accepted = true }
        Keys.onLeftPressed: (event) => {
            if (root.gridMode) {
                root.moveGrid(-1)
                event.accepted = true
            }
        }
        Keys.onRightPressed: (event) => {
            if (root.gridMode) {
                root.moveGrid(1)
                event.accepted = true
            }
        }
    }

    Process {
        id: searchProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                line = line.trim()
                if (line !== "") {
                    var parts = line.lastIndexOf("/")
                    var name = parts >= 0 ? line.substring(parts + 1) : line
                    var dir = parts > 0 ? line.substring(0, parts) : ""
                    fileModel.append({ path: line, name: name, dir: dir })
                }
            }
        }
        onExited: {
            searching = false
            fileList.currentIndex = 0
            fileGrid.currentIndex = 0
        }
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        text: "Files"
        color: Colorscheme.on_surface
        font.pixelSize: 18
        font.bold: true
    }

    // Search status indicator at top
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        text: searching ? "Searching..." : (fileModel.count > 0 ? fileModel.count + " files" : "")
        color: Colorscheme.on_surface_variant
        font.pixelSize: 12
        visible: searchBox.text.length >= 2
    }

    ListView {
        id: fileList
        anchors.fill: parent
        anchors.topMargin: 42
        clip: true
        visible: !root.gridMode

        model: fileModel
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        highlightMoveDuration: 0
        spacing: 4

        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
            interactive: true
            contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
            background: Rectangle { color: "transparent" }
        }

        highlight: Rectangle {
            color: Colorscheme.primary
            radius: 10
        }

        delegate: Item {
            width: ListView.view.width
            height: 44

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.selectIndex(index)
                }
                onDoubleClicked: root.openSelected()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "description"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface_variant
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: model.name
                        color: ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: model.dir
                        color: ListView.isCurrentItem ? Qt.rgba(0,0,0,0.5) : Colorscheme.on_surface_variant
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        elide: Text.ElideLeft
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    GridView {
        id: fileGrid
        anchors.fill: parent
        anchors.topMargin: 42
        anchors.bottomMargin: 12
        clip: true
        visible: root.gridMode

        model: fileModel
        cellWidth: Math.max(150, Math.min(220, Math.floor((parent.width - 24) / 3)))
        cellHeight: 120
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        highlightMoveDuration: 0
        cacheBuffer: 200

        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
            interactive: true
            contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
            background: Rectangle { color: "transparent" }
        }

        highlight: Rectangle {
            color: Colorscheme.primary
            radius: 12
        }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    selectIndex(index)
                }
                onDoubleClicked: root.openSelected()
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 14
                color: GridView.isCurrentItem ? Colorscheme.primary : Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.06)
                border.width: GridView.isCurrentItem ? 0 : 1
                border.color: Colorscheme.glass_outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "description"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: GridView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface_variant
                    }

                    Text {
                        Layout.fillWidth: true
                        text: model.name
                        color: GridView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: model.dir
                        color: GridView.isCurrentItem ? Qt.rgba(0,0,0,0.5) : Colorscheme.on_surface_variant
                        font.pixelSize: 10
                        font.family: "JetBrains Mono Nerd Font"
                        elide: Text.ElideLeft
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: searchBox.text.length < 2 ? "Type at least 2 characters to search files..." : "No files found"
        color: Colorscheme.on_surface_variant
        font.pixelSize: 14
        visible: fileModel.count === 0 && !searching
    }
}
