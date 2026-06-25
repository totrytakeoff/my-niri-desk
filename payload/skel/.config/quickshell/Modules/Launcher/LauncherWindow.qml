import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io          // 【新增】：必须引入 IO 模块以支持命令行 Process
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: root
    
    visible: false
    color: "transparent" 
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    WlrLayershell.namespace: "rofi-launcher-overlay"
    WlrLayershell.layer: WlrLayer.Overlay 
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive 
    WlrLayershell.exclusionMode: ExclusionMode.Ignore 

    property int currentMode: 0 
    
    // 【核心修复 1】：废除容易被缓存坑的软链接，直接绑定全局真理变量 Colorscheme.currentWallpaperPreview
    property string previewImage: (currentMode === 2 && wallpaperPage.currentSelectedPreview !== "") 
                                  ? wallpaperPage.currentSelectedPreview 
                                  : (Colorscheme.currentWallpaperPreview !== "" ? Colorscheme.currentWallpaperPreview : "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current")

    property bool toolsExpanded: currentMode === 4 && toolsPage.expanded
    property bool launcherGridExpanded: WidgetState.launcherLayoutMode === "grid" && !toolsExpanded

    // ==========================================
    // 【全局壁纸强制同步引擎】
    // ==========================================
    Process {
        id: syncGlobalWallpaper
        // 【核心修改】：已将 swww 替换为 awww
        command: ["bash", "-c", "awww query | awk -F 'image: ' '{print $2}' | head -n 1"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (path) => {
                let currentPath = path.trim().replace(/^"|"$/g, '');
                if (currentPath !== "") {
                    // 获取到真实的绝对路径，强行刷新全局变量，QML 图片缓存瞬间失效并更新
                    Colorscheme.currentWallpaperPreview = "file://" + currentPath;
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            // 【核心修复 2】：每次打开 Launcher，第一时间强制核实并同步系统真实壁纸！
            syncGlobalWallpaper.running = false;
            syncGlobalWallpaper.running = true;

            focusCurrentPage()
            
            // // 每次打开都正常播放入场动画
            // mainUI.opacity = 0.0
            // uiTranslate.y = 300
            // openAnim.start()
            mainUI.opacity = 1.0
            uiTranslate.y = 0
        }
    }

    onCurrentModeChanged: {
        if (visible) {
            focusCurrentPage()
        }
    }

    function requestClose() {
        // if (closeAnim.running || !root.visible) return
        // closeAnim.start()
        if (!root.visible) return
        root.visible = false
    }

    function toggleWindow() {
        if (root.visible) requestClose()
        else root.visible = true 
    }

    function cycleMode(step) {
        const modeCount = 5

        if (!WidgetState.launcherCyclicNavigation) {
            root.currentMode = Math.max(0, Math.min(modeCount - 1, root.currentMode + step))
            return
        }

        root.currentMode = (root.currentMode + step + modeCount) % modeCount
    }

    function focusCurrentPage() {
        if (currentMode === 0) appPage.forceSearchFocus()
        else if (currentMode === 1) windowPage.forceSearchFocus()
        else if (currentMode === 2) wallpaperPage.forceSearchFocus()
        else if (currentMode === 3) filePage.forceSearchFocus()
        else if (currentMode === 4) toolsPage.forceSearchFocus()
        else mainUI.forceActiveFocus()
    }

    function toggleLayoutMode() {
        WidgetState.launcherLayoutMode = WidgetState.launcherLayoutMode === "grid" ? "list" : "grid"
        appPage.refreshSearch()
        focusCurrentPage()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    // ==========================================
    // 主界面 UI
    // ==========================================
    Rectangle {
        id: mainUI
        width: 1008
        height: 567
        
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        
        opacity: 1.0 // 原来是0
        
        transform: Translate {
            id: uiTranslate
            y: 0 // 原来是300
        }
        
        // ParallelAnimation {
        //     id: openAnim
        //     NumberAnimation {
        //         target: mainUI
        //         property: "opacity"
        //         to: 1.0
        //         duration: 400
        //         easing.type: Easing.OutCubic
        //     }
        //     NumberAnimation {
        //         target: uiTranslate
        //         property: "y"
        //         to: 0
        //         duration: 700
        //         easing.type: Easing.OutBack
        //         easing.overshoot: 2.5
        //     }
        // }
        //
        // ParallelAnimation {
        //     id: closeAnim
        //     NumberAnimation {
        //         target: mainUI
        //         property: "opacity"
        //         to: 0.0
        //         duration: 300
        //         easing.type: Easing.InCubic
        //     }
        //     NumberAnimation {
        //         target: uiTranslate
        //         property: "y"
        //         to: 300
        //         duration: 300
        //         easing.type: Easing.InCubic
        //     }
        //     onFinished: root.visible = false 
        // }
        
        color: "transparent" 
        radius: 20 
        focus: true 
        
        // 全局键盘网关
        Keys.onUpPressed: (event) => {
            if (root.currentMode === 0) appPage.decrementCurrentIndex()
            else if (root.currentMode === 1) windowPage.decrementCurrentIndex()
            else if (root.currentMode === 2) wallpaperPage.decrementCurrentIndex()
            else if (root.currentMode === 3) filePage.decrementCurrentIndex()
            else if (root.currentMode === 4) toolsPage.decrementCurrentIndex()
            event.accepted = true
        }
        
        Keys.onDownPressed: (event) => {
            if (root.currentMode === 0) appPage.incrementCurrentIndex()
            else if (root.currentMode === 1) windowPage.incrementCurrentIndex()
            else if (root.currentMode === 2) wallpaperPage.incrementCurrentIndex()
            else if (root.currentMode === 3) filePage.incrementCurrentIndex()
            else if (root.currentMode === 4) toolsPage.incrementCurrentIndex()
            event.accepted = true
        }

        Keys.onReturnPressed: (event) => {
            if (root.currentMode === 0) appPage.runSelectedApp()
            else if (root.currentMode === 1) windowPage.focusSelectedWindow()
            else if (root.currentMode === 2) wallpaperPage.applyWallpaper()
            else if (root.currentMode === 3) filePage.openSelected()
            else if (root.currentMode === 4) toolsPage.activateCurrentTool()
            event.accepted = true
        }
        
        Keys.onEnterPressed: (event) => {
            if (root.currentMode === 0) appPage.runSelectedApp()
            else if (root.currentMode === 1) windowPage.focusSelectedWindow()
            else if (root.currentMode === 2) wallpaperPage.applyWallpaper()
            else if (root.currentMode === 3) filePage.openSelected()
            else if (root.currentMode === 4) toolsPage.activateCurrentTool()
            event.accepted = true
        }

        Keys.onEscapePressed: (event) => {
            if (root.launcherGridExpanded) {
                WidgetState.launcherLayoutMode = "list"
                appPage.refreshSearch()
                root.focusCurrentPage()
            } else if (root.toolsExpanded) {
                toolsPage.collapse()
            } else {
                root.requestClose()
            }
            event.accepted = true
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Backtab) {
                root.cycleMode(-1)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.cycleMode(-1)
                } else {
                    root.cycleMode(1)
                }
                event.accepted = true
                return
            }

            if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_G) {
                root.toggleLayoutMode()
                event.accepted = true
            }
        }
        
        MouseArea { anchors.fill: parent } 
        
        Rectangle {
            id: globalMask
            anchors.fill: parent
            radius: 20
            visible: false
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: globalMask
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                
                // --- 左侧：海报区 / 翻译展开区 / 应用网格展开 ---
                Item {
                    Layout.preferredWidth: root.launcherGridExpanded ? 80 : (root.toolsExpanded ? 640 : 640)
                    Layout.fillHeight: true
                    clip: true

                    // 壁纸背景（非翻译/非网格展开时显示）
                    Item {
                        anchors.fill: parent
                        visible: !root.toolsExpanded && !root.launcherGridExpanded

                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                        }

                        Image {
                            id: rawPreviewForBlur
                            width: 1008
                            height: 567
                            x: 0; y: 0
                            source: root.previewImage
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                            sourceSize.width: 1008
                            sourceSize.height: 567
                        }

                        FastBlur {
                            anchors.fill: rawPreviewForBlur
                            source: rawPreviewForBlur
                            radius: 64
                            transparentBorder: false
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.2)
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 80
                            clip: true

                            Image {
                                width: 1008
                                height: 567
                                x: -80; y: 0
                                fillMode: Image.PreserveAspectCrop
                                source: root.previewImage
                                asynchronous: true
                                sourceSize.width: 1008
                                sourceSize.height: 567
                            }
                        }
                    }

                    // 翻译展开内容（翻译展开时显示）
                    Item {
                        anchors.fill: parent
                        visible: root.toolsExpanded

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0.04, 0.04, 0.08, 0.95)
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.leftMargin: 96
                            anchors.rightMargin: 24
                            anchors.topMargin: 24
                            anchors.bottomMargin: 24
                            clip: true
                            contentHeight: transOutput.implicitHeight

                            TextEdit {
                                id: transOutput
                                width: parent.width
                                text: toolsPage.translating ? "Translating..." : toolsPage.resultText
                                color: Colorscheme.on_surface
                                font.pixelSize: 14
                                font.family: "JetBrains Mono Nerd Font"
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                selectByMouse: true
                                readOnly: true
                                cursorVisible: false
                                activeFocusOnTab: false
                            }
                        }
                    }

                    Column {
                        width: 80
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 24
                        
                        // 标签页 1：应用
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.currentMode === 0 ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 20
                                color: root.currentMode === 0 ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }
                        }
                        
                        // 标签页 2：窗口
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.currentMode === 1 ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 20
                                color: root.currentMode === 1 ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }
                        }
                        
                        // 标签页 3：壁纸
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.currentMode === 2 ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 20
                                color: root.currentMode === 2 ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }
                        }
                        
                        // 标签页 4：文件检索
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.currentMode === 3 ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 20
                                color: root.currentMode === 3 ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }
                        }
                        
                        // 标签页 5：常用工具
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.currentMode === 4 ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 20
                                color: root.currentMode === 4 ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }
                        }

                        // 网格/列表切换（全局 Launcher 布局）
                        Rectangle {
                            width: 36; height: 36; radius: 18
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: WidgetState.launcherLayoutMode === "grid" ? Colorscheme.secondary : Qt.rgba(0.06, 0.06, 0.1, 0.8)

                            Text {
                                anchors.centerIn: parent
                                text: WidgetState.launcherLayoutMode === "grid" ? "▦" : "☰"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 16
                                color: WidgetState.launcherLayoutMode === "grid" ? Qt.rgba(0.06, 0.06, 0.1, 1.0) : Colorscheme.secondary
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleLayoutMode()
                            }
                        }
                    }
                }
                
                // --- 右侧：列表区 ---
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.06, 0.06, 0.1, 0.85) 
                    }
                    
                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: 30
                        currentIndex: root.currentMode 
                        
                        AppPage { 
                            id: appPage 
                            onRequestCloseLauncher: root.requestClose()
                        }
                        WindowPage { 
                            id: windowPage 
                            onRequestCloseLauncher: root.requestClose()
                        }
                        WallpaperPage { 
                            id: wallpaperPage  
                            onRequestCloseLauncher: root.requestClose()
                        }
                        FilePage {
                            id: filePage
                            onRequestCloseLauncher: root.requestClose()
                        }
                        ToolsPage {
                            id: toolsPage
                            onRequestCloseLauncher: root.requestClose()
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Colorscheme.secondary_fixed
            border.width: 2
            radius: 20
        }
    }
}
