import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

import "../../JS/AppManager.js" as AppManager

Item {
    id: root

    signal requestCloseLauncher()

    property var filteredAppsModel: []
    property bool gridMode: false

    function decrementCurrentIndex() {
        if (gridMode) grid.decrementCurrentIndex()
        else appsList.decrementCurrentIndex()
    }
    function incrementCurrentIndex() {
        if (gridMode) grid.incrementCurrentIndex()
        else appsList.incrementCurrentIndex()
    }
    function forceSearchFocus() { searchBox.forceActiveFocus() }

    function search(text) {
        filteredAppsModel = AppManager.updateFilter(text, DesktopEntries, WidgetState.launcherSortMode)
        if (gridMode) grid.currentIndex = 0
        else appsList.currentIndex = 0
    }

    function toggleGrid() {
        gridMode = !gridMode
        search(searchBox.text)
        forceSearchFocus()
    }

    function refreshSearch() {
        search(searchBox.text)
        persistState()
    }

    Keys.onPressed: (event) => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_G) {
            toggleGrid()
            event.accepted = true
        }
    }

    Timer {
        id: startupPollTimer
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (DesktopEntries.applications.values.length > 0) {
                root.search(searchBox.text)
                running = false
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
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

    function launchApp(appData) {
        let appId = appData.id || appData.name
        if (appId) {
            AppManager.recordLaunch(appId)
            root.persistState()
            Quickshell.execDetached(["desk-app-run", "--desktop", appId])
        } else if (appData.appObj) {
            appData.appObj.execute()
        }
    }

    Component.onCompleted: {
        loadFreqProcess.running = true
    }

    function persistState() {
        var state = JSON.stringify({
            sortMode: WidgetState.launcherSortMode,
            freq: AppManager._freqData
        })
        saveFreqProcess.running = false
        saveFreqProcess.command = ["bash", "-c",
            "mkdir -p $HOME/.cache/my-desk && printf '%s' '" + state.replace(/'/g, "'\\''") + "' > $HOME/.cache/my-desk/launcher-freq.json"]
        saveFreqProcess.running = true
    }

    Process {
        id: loadFreqProcess
        command: ["bash", "-c", "cat $HOME/.cache/my-desk/launcher-freq.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var parsed = JSON.parse(data.trim())
                    if (parsed.freq) AppManager.setFreqData(parsed.freq)
                    else AppManager.setFreqData(parsed)
                    if (parsed.sortMode === "alphabetical" || parsed.sortMode === "frequent") {
                        WidgetState.launcherSortMode = parsed.sortMode
                    }
                } catch (e) {
                    AppManager.setFreqData({})
                }
            }
        }
    }

    Process { id: saveFreqProcess }

    TextInput {
        id: searchBox
        x: -1000; y: -1000
        width: 0; height: 0
        opacity: 0; visible: true

        onTextChanged: root.search(text)
        Keys.onReturnPressed: (event) => { runSelectedApp(); event.accepted = true }
        Keys.onEnterPressed: (event) => { runSelectedApp(); event.accepted = true }
        Keys.onUpPressed: (event) => { root.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { root.incrementCurrentIndex(); event.accepted = true }
        Keys.onLeftPressed: (event) => { if (root.gridMode) { grid.decrementCurrentIndex(); event.accepted = true } }
        Keys.onRightPressed: (event) => { if (root.gridMode) { grid.incrementCurrentIndex(); event.accepted = true } }
    }

    // 列表视图
    ListView {
        id: appsList
        anchors.fill: parent
        anchors.topMargin: 4
        clip: true
        visible: !gridMode

        model: filteredAppsModel
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation

        ScrollBar.vertical: ScrollBar {
            width: 6; policy: ScrollBar.AsNeeded; interactive: true
            contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
            background: Rectangle { color: "transparent" }
        }

        highlight: Rectangle { color: Colorscheme.primary; radius: 12 }
        highlightMoveDuration: 0

        delegate: Item {
            width: ListView.view.width; height: 56

            MouseArea {
                anchors.fill: parent
                onClicked: { appsList.currentIndex = index; runSelectedApp() }
            }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 16

                Image {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    sourceSize.width: 64; sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                    source: {
                        let ic = modelData.icon
                        if (!ic) return ""
                        if (ic.startsWith("/")) return "file://" + ic
                        if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                        return "image://icon/" + ic
                    }
                }

                Text {
                    text: root.highlightText(modelData.name, searchBox.text)
                    textFormat: Text.StyledText
                    color: ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    font.pixelSize: 16; font.bold: false; Layout.fillWidth: true
                }

                Text {
                    visible: WidgetState.launcherSortMode === "frequent" && modelData.freq > 0
                    text: String(modelData.freq)
                    color: ListView.isCurrentItem ? Qt.rgba(0,0,0,0.5) : Colorscheme.on_surface_variant
                    font.pixelSize: 11; font.family: "JetBrains Mono Nerd Font"; opacity: 0.6
                }
            }
        }
    }

    // 网格视图
    GridView {
        id: grid
        anchors.fill: parent
        anchors.topMargin: 4
        clip: true
        visible: gridMode

        model: filteredAppsModel
        cellWidth: Math.max(90, Math.min(120, Math.floor((parent.width - 20) / 5)))
        cellHeight: 110
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        highlightMoveDuration: 0
        cacheBuffer: 200

        ScrollBar.vertical: ScrollBar {
            width: 6; policy: ScrollBar.AsNeeded; interactive: true
            contentItem: Rectangle { radius: 3; color: Colorscheme.on_surface_variant; opacity: 0.4 }
            background: Rectangle { color: "transparent" }
        }

        highlight: Rectangle { color: Colorscheme.primary; radius: 14 }

        delegate: Item {
            width: GridView.view.cellWidth; height: GridView.view.cellHeight

            MouseArea {
                anchors.fill: parent
                onClicked: { grid.currentIndex = index; runSelectedApp() }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56; height: 56; radius: 14
                    color: GridView.isCurrentItem ? Colorscheme.on_primary : Qt.alpha(Colorscheme.primary_container, 0.5)
                    border.width: GridView.isCurrentItem ? 0 : 1
                    border.color: Colorscheme.glass_outline

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                        source: {
                            let ic = modelData.icon
                            if (!ic) return ""
                            if (ic.startsWith("/")) return "file://" + ic
                            if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                            return "image://icon/" + ic
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.name
                    color: GridView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    function runSelectedApp() {
        var model = gridMode ? grid.model : appsList.model
        var idx = gridMode ? grid.currentIndex : appsList.currentIndex
        if (model && model.length > 0 && idx >= 0) {
            var appData = model[idx]
            if (appData && appData.appObj) {
                root.launchApp(appData)
            }
            root.requestCloseLauncher()
        }
    }
}
