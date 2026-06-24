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

    ListModel { id: fileModel }

    function decrementCurrentIndex() { fileList.decrementCurrentIndex() }
    function incrementCurrentIndex() { fileList.incrementCurrentIndex() }
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
        if (fileModel.count === 0 || fileList.currentIndex < 0) return
        var path = fileModel.get(fileList.currentIndex).path
        Quickshell.execDetached(["xdg-open", path])
        root.requestCloseLauncher()
    }

    function openWithVSCode() {
        if (fileModel.count === 0 || fileList.currentIndex < 0) return
        var path = fileModel.get(fileList.currentIndex).path
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
        Keys.onUpPressed: (event) => { fileList.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { fileList.incrementCurrentIndex(); event.accepted = true }
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
        }
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
        anchors.topMargin: 24
        clip: true

        model: fileModel
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        highlightMoveDuration: 0
        spacing: 4

        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
            interactive: true
            contentItem: Rectangle {
                radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4
            }
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
                    fileList.currentIndex = index
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

    Text {
        anchors.centerIn: parent
        text: searchBox.text.length < 2 ? "Type at least 2 characters to search files..." : "No files found"
        color: Colorscheme.on_surface_variant
        font.pixelSize: 14
        visible: fileModel.count === 0 && !searching
    }
}
