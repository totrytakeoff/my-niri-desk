import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config
import qs.Services 

Item {
    id: root
    
    signal requestCloseLauncher()

    readonly property bool gridMode: WidgetState.launcherLayoutMode === "grid"
    ListModel { id: filteredWindows }

    function normalizedIndex(index, count) {
        if (count <= 0) return -1
        if (WidgetState.launcherCyclicNavigation) return (index % count + count) % count
        return Math.max(0, Math.min(index, count - 1))
    }

    function selectIndex(index) {
        if (filteredWindows.count === 0) return
        var idx = normalizedIndex(index, filteredWindows.count)
        windowsList.currentIndex = idx
        windowsGrid.currentIndex = idx
        if (root.gridMode) windowsGrid.positionViewAtIndex(idx, GridView.Contain)
        else windowsList.positionViewAtIndex(idx, ListView.Contain)
    }

    function gridColumns() {
        return Math.max(1, Math.floor(windowsGrid.width / windowsGrid.cellWidth))
    }

    function moveGrid(delta) {
        selectIndex(windowsGrid.currentIndex + delta)
    }
    
    function decrementCurrentIndex() {
        if (gridMode) moveGrid(-gridColumns())
        else selectIndex(windowsList.currentIndex - 1)
    }
    function incrementCurrentIndex() {
        if (gridMode) moveGrid(gridColumns())
        else selectIndex(windowsList.currentIndex + 1)
    }
    function forceSearchFocus() { searchBox.forceActiveFocus() }

    // ==========================================
    // 正则清洗器：去除前后缀，保留原本的首字母大小写
    // ==========================================
    function cleanAppName(rawName, isAppId) {
        if (!rawName) return ""
        let name = rawName

        if (isAppId) {
            // 切掉域名前缀 (如 org.kde.dolphin -> dolphin)
            name = name.replace(/^([a-z0-9\-]+\.)+/gi, "")
            // 切掉 .desktop 后缀
            name = name.replace(/\.desktop$/gi, "")
            // 注意：已移除首字母强制大写的逻辑，保留原生大小写
        } else {
            // 切掉窗口标题后面的浏览器/编辑器后缀尾巴
            name = name.replace(/\s*[-—|]\s*(Mozilla Firefox|Google Chrome|Chromium|Brave|Edge|Vivaldi|Visual Studio Code|Kate|KWrite).*$/gi, "")
        }

        return name
    }

    function search(text) {
        var previousWinId = null
        var activeIndex = root.gridMode ? windowsGrid.currentIndex : windowsList.currentIndex
        if (activeIndex >= 0 && activeIndex < filteredWindows.count) {
            previousWinId = filteredWindows.get(activeIndex).winId
        }

        filteredWindows.clear()
        let q = text.toLowerCase()
        var nextIndex = -1
        
        for(let i = 0; i < Niri.windows.count; i++) {
            let item = Niri.windows.get(i)
            if(item.title.toLowerCase().includes(q) || item.appId.toLowerCase().includes(q)) {
                filteredWindows.append({
                    title: item.title,
                    appId: item.appId, 
                    winId: item.winId
                })
                if (previousWinId !== null && item.winId === previousWinId) {
                    nextIndex = filteredWindows.count - 1
                }
            }
        }
        if (nextIndex < 0 && filteredWindows.count > 0) {
            nextIndex = Math.min(Math.max(activeIndex, 0), filteredWindows.count - 1)
        }
        if (nextIndex >= 0) selectIndex(nextIndex)
        else {
            windowsList.currentIndex = -1
            windowsGrid.currentIndex = -1
        }
    }

    Connections {
        target: Niri
        function onWindowsUpdated() {
            if (root.visible) {
                root.search(searchBox.text)
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            Niri.reloadWindows()
            searchBox.text = ""
            search("")
        }
    }

    function highlightText(fullText, query) {
        let safeText = fullText.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        if (!query || query.trim() === "") return safeText
        let escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        let regex = new RegExp("(" + escapedQuery + ")", "gi")
        return safeText.replace(regex, "<u><b>$1</b></u>")
    }

    TextInput {
        id: searchBox
        x: -1000 
        y: -1000
        width: 0
        height: 0
        opacity: 0
        visible: true 
        
        onTextChanged: {
            root.search(text)
        }
        Keys.onReturnPressed: (event) => { focusSelectedWindow(); event.accepted = true }
        Keys.onEnterPressed: (event) => { focusSelectedWindow(); event.accepted = true }
        Keys.onUpPressed: (event) => { root.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { root.incrementCurrentIndex(); event.accepted = true }
        Keys.onLeftPressed: (event) => { if (root.gridMode) { root.moveGrid(-1); event.accepted = true } }
        Keys.onRightPressed: (event) => { if (root.gridMode) { root.moveGrid(1); event.accepted = true } }
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        text: "Windows"
        color: Colorscheme.on_surface
        font.pixelSize: 18
        font.bold: true
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 42

        Text {
            anchors.centerIn: parent 
            text: "No windows opened."
            color: Colorscheme.on_surface_variant
            font.pixelSize: 16
            visible: filteredWindows.count === 0
        }

        ListView {
            id: windowsList
            anchors.fill: parent
            clip: true
            visible: !root.gridMode
            
            model: filteredWindows
            
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: WidgetState.launcherCyclicNavigation
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

            delegate: Item {
                id: delegateItem 
                width: ListView.view.width
                height: 56

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectIndex(index)
                        focusSelectedWindow()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 16

                    Item {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36

                        Image {
                            id: windowIcon
                            anchors.fill: parent
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            
                            property int attempt: 0
                            
                            property string rawId: model.appId || ""
                            property string lowerId: rawId.toLowerCase()

                            // 优先走系统图标主题，再退回到通用执行文件图标。
                            property var candidates: [
                                "image://icon/" + rawId,                                                  
                                "image://icon/" + lowerId,                                                
                                "image://icon/application-x-executable"                                   
                            ]
                            
                            source: {
                                let ic = candidates[attempt]
                                if (ic.startsWith("/")) return "file://" + ic
                                return ic
                            }
                            
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    if (attempt < candidates.length - 1) {
                                        attempt++ 
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: root.highlightText(root.cleanAppName(model.title, false), searchBox.text)
                        textFormat: Text.StyledText 
                        color: delegateItem.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                        font.pixelSize: 16
                        font.bold: false 
                        elide: Text.ElideRight 
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.highlightText(root.cleanAppName(model.appId, true), searchBox.text)
                        textFormat: Text.StyledText 
                        color: delegateItem.ListView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.7) : Colorscheme.on_surface_variant
                        font.pixelSize: 12
                        font.family: "JetBrains Mono Nerd Font"
                    }
                }
            }
        }

        GridView {
            id: windowsGrid
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            clip: true
            visible: root.gridMode

            model: filteredWindows
            cellWidth: Math.max(1, Math.floor((width - 24) / 4))
            cellHeight: 140
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
                        root.selectIndex(index)
                        focusSelectedWindow()
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
                        anchors.margins: 14
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44

                            Image {
                                anchors.fill: parent
                                sourceSize.width: 64
                                sourceSize.height: 64
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                property string rawId: model.appId || ""
                                source: rawId ? "image://icon/" + rawId : "image://icon/application-x-executable"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.highlightText(root.cleanAppName(model.title, false), searchBox.text)
                            textFormat: Text.StyledText
                            color: GridView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.highlightText(root.cleanAppName(model.appId, true), searchBox.text)
                            textFormat: Text.StyledText
                            color: GridView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.7) : Colorscheme.on_surface_variant
                            font.pixelSize: 11
                            font.family: "JetBrains Mono Nerd Font"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    function focusSelectedWindow() {
        var idx = root.gridMode ? windowsGrid.currentIndex : windowsList.currentIndex
        if (filteredWindows.count > 0 && idx >= 0) {
            let winId = filteredWindows.get(idx).winId
            focusProcess.command = ["niri", "msg", "action", "focus-window", "--id", winId]
            focusProcess.running = true
        }
    }
    
    Process { 
        id: focusProcess
        onExited: {
            running = false 
            // root.requestCloseLauncher()
        }
    }
}
