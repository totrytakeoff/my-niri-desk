import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root
    
    signal requestCloseLauncher()

    property string wallpaperPath: Quickshell.env("HOME") + "/.config/wallpaper"
    readonly property bool gridMode: WidgetState.launcherLayoutMode === "grid"
    
    property string currentSelectedPreview: ""
    property bool isLoading: true

    ListModel { id: wallpaperModel }

    function normalizedIndex(index, count) {
        if (count <= 0) return -1
        if (WidgetState.launcherCyclicNavigation) return (index % count + count) % count
        return Math.max(0, Math.min(index, count - 1))
    }

    function selectIndex(index) {
        if (wallpaperModel.count === 0) return
        var idx = normalizedIndex(index, wallpaperModel.count)
        wallpaperList.currentIndex = idx
        wallpaperGrid.currentIndex = idx
        root.currentSelectedPreview = "file://" + wallpaperModel.get(idx).path
        if (root.gridMode) wallpaperGrid.positionViewAtIndex(idx, GridView.Contain)
        else wallpaperList.positionViewAtIndex(idx, ListView.Contain)
    }

    function gridColumns() {
        return Math.max(1, Math.floor(wallpaperGrid.width / wallpaperGrid.cellWidth))
    }

    function moveGrid(delta) {
        selectIndex(wallpaperGrid.currentIndex + delta)
    }

    function decrementCurrentIndex() {
        if (gridMode) moveGrid(-gridColumns())
        else selectIndex(wallpaperList.currentIndex - 1)
    }
    function incrementCurrentIndex() {
        if (gridMode) moveGrid(gridColumns())
        else selectIndex(wallpaperList.currentIndex + 1)
    }

    function forceSearchFocus() { keySink.forceActiveFocus() }

    TextInput {
        id: keySink
        x: -1000; y: -1000
        width: 0; height: 0
        opacity: 0; visible: true

        Keys.onReturnPressed: (event) => { root.applyWallpaper(); event.accepted = true }
        Keys.onEnterPressed: (event) => { root.applyWallpaper(); event.accepted = true }
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

    // ==========================================
    // 壁纸扫描引擎
    // ==========================================
    Process {
        id: scanWallpapers
        command: ["bash", "-c", "find " + root.wallpaperPath + " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        running: false 
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (file) => {
                if (file.trim() !== "") {
                    let name = file.substring(file.lastIndexOf("/") + 1)
                    wallpaperModel.append({ path: file.trim(), fileName: name })
                }
            }
        }
        onExited: {
            root.isLoading = false
            
            // 直接白嫖 LauncherWindow 刚打开时就已经查好的全局变量
            let currentPath = Colorscheme.currentWallpaperPreview.replace("file://", "");
            
            if (currentPath === "") return;

            for (let i = 0; i < wallpaperModel.count; i++) {
                if (wallpaperModel.get(i).path === currentPath) {
                    selectIndex(i)
                    root.currentSelectedPreview = Colorscheme.currentWallpaperPreview;
                    break;
                }
            }
        }
    }

    // 删除了原先冗余的 Process { id: getCurrentWallpaper ... } 

    onVisibleChanged: {
        if (visible) {
            wallpaperModel.clear()
            root.isLoading = true
            scanWallpapers.running = true
        } 
    }

    // ==========================================
    // UI 渲染层
    // ==========================================
    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        text: "Wallpapers"
        color: Colorscheme.on_surface
        font.pixelSize: 18
        font.bold: true
    }

    Text {
        anchors.centerIn: parent 
        text: "Scanning wallpapers..."
        color: Colorscheme.on_surface_variant
        font.pixelSize: 16
        visible: root.isLoading
    }

    ListView {
        id: wallpaperList
        anchors.fill: parent
        anchors.topMargin: 42
        clip: true
        model: wallpaperModel
        
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        visible: !root.gridMode

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
        highlightMoveDuration: 0 

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < count) {
                root.currentSelectedPreview = "file://" + wallpaperModel.get(currentIndex).path
            }
        }

        delegate: Item {
            id: delegateItem 
            width: ListView.view.width
            height: 56

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    selectIndex(index)
                    applyWallpaper()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 16
                spacing: 16

                Image {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 36
                    source: "file://" + model.path
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 128
                    sourceSize.height: 72
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }

                Text {
                    text: model.fileName
                    color: delegateItem.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    font.pixelSize: 16
                    font.bold: false 
                    elide: Text.ElideRight 
                    Layout.fillWidth: true
                }
            }
        }
    }

    GridView {
        id: wallpaperGrid
        anchors.fill: parent
        anchors.topMargin: 42
        anchors.bottomMargin: 12
        clip: true
        model: wallpaperModel
        visible: root.gridMode

        cellWidth: Math.max(1, Math.floor((width - 24) / 4))
        cellHeight: 160
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

        highlight: Rectangle { color: Colorscheme.primary; radius: 14 }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    selectIndex(index)
                    applyWallpaper()
                }
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
                    anchors.margins: 10
                    spacing: 8

                    Image {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        source: "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 256
                        sourceSize.height: 144
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }

                    Text {
                        Layout.fillWidth: true
                        text: model.fileName
                        color: GridView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // ==========================================
    // 脚本执行引擎
    // ==========================================
    function applyWallpaper() {
        var idx = root.gridMode ? wallpaperGrid.currentIndex : wallpaperList.currentIndex
        if (wallpaperModel.count === 0 || idx < 0) return
        
        if (runScript.running) {
            console.log("Wallpaper switch in progress, ignoring extra triggers...")
            return
        }
        
        let currentPath = wallpaperModel.get(idx).path
        
        Colorscheme.currentWallpaperPreview = "file://" + currentPath;
        let home = Quickshell.env("HOME")
        
        // 【核心修改】：
        // 1. 将 swww img 改为 awww img
        // 2. 为 matugen 加上 --source-color-index 0
        let scriptContent = "awww img '" + currentPath + "' --transition-type any --transition-duration 3 --transition-fps 60 --transition-bezier .43,1.19,1,.4;\n" +
                            "matugen image '" + currentPath + "' --source-color-index 0;\n" +
                            "desk-run overview '" + currentPath + "'"
                           
        runScript.command = ["bash", "-c", scriptContent]
        runScript.running = true
    }

    Process { id: runScript }
}
