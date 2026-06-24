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

    function decrementCurrentIndex() { appsList.decrementCurrentIndex() }
    function incrementCurrentIndex() { appsList.incrementCurrentIndex() }
    function forceSearchFocus() { searchBox.forceActiveFocus() }

    function search(text) {
        filteredAppsModel = AppManager.updateFilter(text, DesktopEntries, WidgetState.launcherSortMode)
        appsList.currentIndex = 0
    }

    // ==========================================
    // 异步等待机制
    // ==========================================
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
            saveFreqProcess.running = false
            saveFreqProcess.command = ["bash", "-c",
                "mkdir -p $HOME/.cache/my-desk && printf '%s' '" + JSON.stringify(freqSnapshot()) + "' > $HOME/.cache/my-desk/launcher-freq.json"]
            saveFreqProcess.running = true
            Quickshell.execDetached(["desk-app-run", "--desktop", appId])
        } else if (appData.appObj) {
            appData.appObj.execute()
        }
    }

    function freqSnapshot() {
        return AppManager._freqData
    }

    Component.onCompleted: {
        loadFreqProcess.running = true
    }

    Process {
        id: loadFreqProcess
        command: ["bash", "-c", "cat $HOME/.cache/my-desk/launcher-freq.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var parsed = JSON.parse(data.trim())
                    AppManager.setFreqData(parsed)
                } catch (e) {
                    AppManager.setFreqData({})
                }
            }
        }
    }

    Process {
        id: saveFreqProcess
    }

    TextInput {
        id: searchBox
        x: -1000
        y: -1000
        width: 0
        height: 0
        opacity: 0
        visible: true

        onTextChanged: root.search(text)
        Keys.onReturnPressed: (event) => { runSelectedApp(); event.accepted = true }
        Keys.onEnterPressed: (event) => { runSelectedApp(); event.accepted = true }
        Keys.onUpPressed: (event) => { appsList.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { appsList.incrementCurrentIndex(); event.accepted = true }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 32
        height: 32
        radius: 8
        color: sortMouse.containsMouse ? Colorscheme.surface_variant : "transparent"
        border.width: 1
        border.color: Colorscheme.glass_outline
        z: 1

        Text {
            anchors.centerIn: parent
            text: WidgetState.launcherSortMode === "frequent" ? "sort" : "A-Z"
            font.family: WidgetState.launcherSortMode === "frequent" ? "Material Symbols Rounded" : "JetBrains Mono Nerd Font"
            font.pixelSize: WidgetState.launcherSortMode === "frequent" ? 18 : 14
            font.bold: WidgetState.launcherSortMode !== "frequent"
            color: WidgetState.launcherSortMode === "frequent" ? Colorscheme.primary : Colorscheme.on_surface_variant
        }

        MouseArea {
            id: sortMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                WidgetState.launcherSortMode = WidgetState.launcherSortMode === "frequent" ? "alphabetical" : "frequent"
                root.search(searchBox.text)
            }
        }
    }

    ListView {
        id: appsList
        anchors.fill: parent
        anchors.topMargin: 42
        clip: true

        model: filteredAppsModel

        boundsBehavior: Flickable.StopAtBounds
        keyNavigationWraps: WidgetState.launcherCyclicNavigation
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - 56

        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
            interactive: true
            contentItem: Rectangle {
                radius: 3
                color: Colorscheme.on_surface_variant
                opacity: 0.4
            }
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
                    appsList.currentIndex = index
                    runSelectedApp()
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
                        anchors.fill: parent
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true

                        source: {
                            let ic = modelData.icon
                            if (!ic) return ""
                            if (ic.startsWith("/")) return "file://" + ic
                            if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                            return "image://icon/" + ic
                        }

                        property int failCount: 0

                        onStatusChanged: {
                            if (status === Image.Error) {
                                failCount++
                                if (failCount === 1) {
                                    source = "image://icon/" + modelData.fallbackIcon
                                } else if (failCount === 2) {
                                    source = "image://icon/application-x-executable"
                                }
                            }
                        }
                    }
                }

                Text {
                    text: root.highlightText(modelData.name, searchBox.text)
                    textFormat: Text.StyledText
                    color: delegateItem.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    font.pixelSize: 16
                    font.bold: false
                    Layout.fillWidth: true
                }

                Text {
                    visible: WidgetState.launcherSortMode === "frequent" && modelData.freq > 0
                    text: String(modelData.freq)
                    color: delegateItem.ListView.isCurrentItem ? Qt.rgba(0, 0, 0, 0.5) : Colorscheme.on_surface_variant
                    font.pixelSize: 11
                    font.family: "JetBrains Mono Nerd Font"
                    opacity: 0.6
                }
            }
        }
    }

    function runSelectedApp() {
        if (filteredAppsModel.length > 0 && appsList.currentIndex >= 0) {
            let appData = filteredAppsModel[appsList.currentIndex]
            if (appData && appData.appObj) {
                root.launchApp(appData)
            }
            root.requestCloseLauncher()
        }
    }
}
