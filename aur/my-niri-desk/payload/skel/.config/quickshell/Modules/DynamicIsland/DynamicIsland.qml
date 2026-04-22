import QtQuick
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io  
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick.Controls
import qs.Services
import qs.config

import qs.Modules.DynamicIsland.ClockContent
import qs.Modules.DynamicIsland.MediaContent  
import qs.Modules.DynamicIsland.NotificationContent
import qs.Modules.DynamicIsland.VolumeContent
import qs.Modules.DynamicIsland.LyricsContent 
import qs.Modules.DynamicIsland.Hub
import qs.Modules.DynamicIsland.Tools
import qs.Modules.DynamicIsland.audio 

// 灵动岛根模块
// ---------------------------------------------------------------------------
// 这是当前整套桌面里最复杂的状态机。
//
// 它不是“一个小组件”，而是一个 overlay shell：
// - 收起态：时间 / 通知 / 音量等瞬时状态
// - 展开态：媒体 / hub / tools / audio / lyrics
// - 还负责：
//   - 投影和形状
//   - 键盘焦点策略
//   - IPC 命令（hub/tools/cancelRecord）
//
// 维护这层时，优先理解 3 件事：
// 1. `root` 上各种 showXxx/isXxxMode 的状态关系
// 2. targetW/targetH/targetR 这套尺寸动画来源
// 3. 哪些模式应该拿键盘焦点，哪些只是 toast，不能阻塞输入

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: islandWindow
        required property var modelData
        screen: modelData

        // 收起态尽量做成短胶囊；展开态保留一点两侧耳朵，视觉更完整。
        property int earRadius: (root && root.isCollapsedMode) ? 0 : 12

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Screen.height 
        margins { top: 0 } 
        
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top

        // 只有真正需要交互的模式才抢键盘焦点。
        // 这个逻辑之前修过：通知/音量 toast 不能再阻塞当前应用输入。
        WlrLayershell.keyboardFocus: (root.expanded || root.showHub || root.showTools || root.showAudio || root.showLyrics)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // ============================================================
        // 【物理挖孔层 (Mask Region)】 
        // ============================================================
        Item {
            id: hitBoxRegion
            anchors.top: maskContainer.top
            anchors.bottom: maskContainer.bottom
            anchors.right: maskContainer.right
            anchors.left: detachedRecordContainer.left 
        }

        mask: Region {
            item: hitBoxRegion
        }

        // ============================================================
        // 【阴影源 (Shadow Source)】 
        // ============================================================
        Item {
            id: shadowSource
            anchors.top: maskContainer.top
            anchors.horizontalCenter: maskContainer.horizontalCenter
            width: maskContainer.width
            height: maskContainer.height
            visible: false 

            Canvas {
                id: shadowLeftEar 
                anchors.right: rootShadow.left
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset(); ctx.fillStyle = "rgba(255, 255, 255, 0.18)";
                    ctx.beginPath(); ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0); ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true); ctx.fill();
                }
            }

            Item {
                id: rootShadow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.width
                height: root.height

                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: Qt.rgba(1, 1, 1, 0.18)
                }
            }

            Canvas {
                id: shadowRightEar 
                anchors.left: rootShadow.right
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "rgba(255, 255, 255, 0.18)";
                    ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(0, 0); ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false); ctx.fill();
                }
            }
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: 0
            verticalOffset: 6
            radius: 20
            samples: 32
            color: "#24000000" 
            cached: true
        }

        // 真正的灵动岛壳体。
        // shadowSource 负责投影；这里负责主体形状和内容挂载。
        Item {
            id: maskContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width + (islandWindow.earRadius * 2)
            height: root.height

            Canvas {
                id: leftEar
                anchors.right: root.left
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.color;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);                 
                    ctx.lineTo(width, 0);             
                    ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true);
                    ctx.fill();
                }
                Connections {
                    target: root
                    function onColorChanged() { leftEar.requestPaint() }
                }
            }

            Item {
                id: root
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                property bool showLyrics: false 
                property bool expanded: false
                property bool showVolume: false
                property bool showHub: false
                property bool showTools: false 
                property bool showAudio: false 
                
                property string currentAudioMode: "mic" 
                property int hubTabIndex: 0
                property bool isRecording: false

                property bool isLyricsMode: showLyrics
                property bool isToolsMode: showTools && !isLyricsMode
                property bool isHubMode: showHub && !isToolsMode && !isLyricsMode
                property bool isAudioMode: showAudio && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isVolumeMode: showVolume && !expanded && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isNotifMode: NotificationManager.hasNotifs && !expanded && !showVolume && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isCollapsedMode: !expanded && !isNotifMode && !isVolumeMode && !isAudioMode && !isLyricsMode && !isHubMode && !isToolsMode
                
                // 旧版曾尝试在 overview 上做“挖孔”效果；当前保留占位但已不再使用。
                property bool showOverviewHole: false

                // 各种模式下的目标尺寸。
                property int lyricsW: lyricsWidget.implicitWidth; property int lyricsH: 42 
                property int expandedW: 540; property int expandedH: 210
                // 默认态收成更短更圆的胶囊。
                property int collapsedW: 168; property int collapsedH: 34
                property int recordExtraW: 0 
                property int toolsW: 480; property int toolsH: 72
                property int notifW: 380; property int notifH: (NotificationManager.model.count * 70) + 20
                property int volW: 320; property int volH: 64
                property int audioW: 360; property int audioH: 84 
                
                property color color: Colorscheme.glass_island
                clip: true
                z: 100

                // 根据当前模式决定目标圆角和尺寸，所有展开/收起动画都由这里驱动。
                property int targetR: (expanded || isNotifMode || isVolumeMode || 
                      isLyricsMode || isHubMode || isToolsMode || isAudioMode) 
                      ? 24 : Math.round(targetH / 2)

                property int targetW: isAudioMode ? audioW :
                    isToolsMode ? toolsW :
                    isHubMode ? hub.implicitWidth : 
                    isLyricsMode ? lyricsW : 
                    expanded ? expandedW : 
                    isVolumeMode ? volW : 
                    isNotifMode ? notifW : 
                    (collapsedW + (root.isRecording ? recordExtraW : 0) + (isCollapsedMode && islandMouseArea.containsMouse ? 12 : 0))

                property int targetH: isAudioMode ? audioH :
                        isToolsMode ? toolsH : 
                        isHubMode ? hub.implicitHeight : 
                        isLyricsMode ? lyricsH : 
                        expanded ? expandedH : 
                        isVolumeMode ? volH : 
                        isNotifMode ? notifH : 
                        (collapsedH + (isCollapsedMode && islandMouseArea.containsMouse ? 4 : 0))

                property real wDamping: 1.0
                property real hDamping: 1.0
                property real rDamping: 1.0

                width: targetW
                height: targetH
                property real radius: targetR

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.color
                    border.width: 1
                    border.color: Colorscheme.glass_outline
                }

                onTargetWChanged: {
                    let isExpanding = (targetW > width); wDamping = isExpanding ? 0.7 : 0.8;
                }
                onTargetHChanged: {
                    let isExpanding = (targetH > height); hDamping = isExpanding ? 0.7 : 0.8;
                }
                onTargetRChanged: {
                    let isExpanding = (targetR > radius); rDamping = isExpanding ? 0.7 : 0.8;
                }

                Behavior on width { SpringAnimation { spring: 5.0; mass: 3.6; damping: root.wDamping; epsilon: 0.01 } }
                Behavior on height { SpringAnimation { spring: 5.0; mass: 3.6; damping: root.hDamping; epsilon: 0.01 } }
                Behavior on radius { SpringAnimation { spring: 5.0; mass: 3.6; damping: root.rDamping; epsilon: 0.01 } }

                IpcHandler {
                    target: "island"
                    
                    // 录制状态取消：给 tools/录屏链路留一个统一复位入口。
                    function cancelRecord() {
                        root.isRecording = false; return "RECORD_CANCELLED"
                    }

                    // 关闭其他模式后再打开 hub/tools，避免多个面板叠在一起。
                    function closeAllOthers() {
                        root.showLyrics = false; root.showTools = false;
                        root.showAudio = false; 
                        root.expanded = false;
                    }

                    function hub() {
                        if (root.showHub) { root.showHub = false; return "HUB_CLOSED" } 
                        else { closeAllOthers(); root.showHub = true; return "HUB_OPENED" }
                    }

                    function tools() {
                        if (root.showTools) { root.showTools = false; return "TOOLS_CLOSED" } 
                        else { closeAllOthers(); root.showHub = false; root.showTools = true; return "TOOLS_OPENED" }
                    }
                }

                PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
               
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

                // 音量 OSD 自动隐藏定时器。
                Timer { 
                    id: volHideTimer
                    interval: 2000
                    onTriggered: {
                        if (volumeWidget.isInteractionActive) { restart() } 
                        else { root.showVolume = false }
                    }
                }
            
                Connections {
                    target: root.audioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerVolumeOSD() } 
                    function onMutedChanged() { root.triggerVolumeOSD() }  
                }
            
                // 只有在没有主动打开 hub/tools/audio 等大面板时，音量变化才显示 OSD。
                function triggerVolumeOSD() {
                    if (root.showHub || root.showTools || root.showAudio || root.expanded || root.showLyrics) return
                    root.showVolume = true; volHideTimer.restart()
                }
                
                property var currentPlayer: null

                Timer {
                    id: stickyTimer
                    interval: 500; repeat: true; triggeredOnStart: true
                    running: Mpris.players.values.length > 0
                    onRunningChanged: { if (!running) root.currentPlayer = null }
                    onTriggered: {
                        var players = Mpris.players.values
                        if (players.length === 0) { root.currentPlayer = null; return }
                        var playingPlayer = null
                        for (let i = 0; i < players.length; i++) { 
                            if (players[i].isPlaying) { playingPlayer = players[i]; break } 
                        }
                        if (playingPlayer) { 
                            if (root.currentPlayer !== playingPlayer) root.currentPlayer = playingPlayer 
                        } else {
                            var currentIsValid = false
                            if (root.currentPlayer) { 
                                for (let i = 0; i < players.length; i++) { 
                                    if (players[i] === root.currentPlayer) { currentIsValid = true; break } 
                                } 
                            }
                            if (!currentIsValid) root.currentPlayer = players[0]
                        }
                    }
                }

                MouseArea {
                    id: islandMouseArea  
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true   
                    enabled: !root.isNotifMode && !root.isVolumeMode 
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.showHub) root.showHub = false 
                            else if (root.showTools) root.showTools = false 
                            else if (root.showAudio) root.showAudio = false
                            
                            root.showLyrics = !root.showLyrics
                            if (root.showLyrics) root.expanded = false
                        } else {
                            if (root.showLyrics) root.showLyrics = false 
                            else if (root.showHub) root.showHub = false   
                            else if (root.showTools) root.showTools = false 
                            else if (root.showAudio) root.showAudio = false
                            else root.expanded = !root.expanded
                        }
                    }
                }

                Shortcut {
                    sequence: "Escape"
                    enabled: !root.isCollapsedMode
                    onActivated: {
                        root.showLyrics = false;
                        root.showTools = false;
                        root.showAudio = false;
                        root.showHub = false;
                        root.showVolume = false;
                        root.expanded = false;
                    }
                }

                Item {
                    id: staticCanvas
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1600 
                    height: 1200

                    ClockContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.collapsedW + (root.isRecording ? root.recordExtraW : 0)
                        height: root.collapsedH
                        
                        player: root.currentPlayer
                        
                        opacity: (!root.expanded && !root.isNotifMode && !root.isVolumeMode && !root.isLyricsMode && !root.isHubMode && !root.isToolsMode && !root.isAudioMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    VolumeContent {
                        id: volumeWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.volW
                        height: root.volH

                        audioNode: root.audioNode
                        opacity: root.isVolumeMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    NotificationContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.notifW - 20
                        height: root.notifH - 20

                        manager: NotificationManager
                        
                        opacity: root.isNotifMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    LyricsContent { 
                        id: lyricsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.lyricsW
                        height: root.lyricsH

                        player: root.currentPlayer; active: root.isLyricsMode
                        opacity: root.isLyricsMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                    
                    MediaContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        width: root.expandedW - 40
                        height: root.expandedH - 40

                        opacity: (root.expanded && !root.isLyricsMode && !root.isHubMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    HubContent {
                        id: hub
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        
                        player: root.currentPlayer
                        currentIndex: root.hubTabIndex
                        onCurrentIndexChanged: root.hubTabIndex = currentIndex
                        onCloseRequested: root.showHub = false

                        opacity: root.isHubMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    ToolsContent {
                        id: toolsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.toolsW
                        height: root.toolsH

                        opacity: root.isToolsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        onRequestHideIsland: { root.showTools = false }
                        onRequestSetRecording: (state) => { root.isRecording = state }
                        onRequestShowAudio: (mode) => { 
                            root.currentAudioMode = mode
                            root.showTools = false
                            root.showAudio = true 
                        }
                    }

                    AudioContent {
                        id: audioWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.audioW
                        height: root.audioH

                        active: root.isAudioMode
                        audioMode: root.currentAudioMode
                        opacity: root.isAudioMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        onRequestStop: {
                            root.showAudio = false
                            toolsWidget.stopAudio() 
                        }
                    }
                }
            }

            Canvas {
                id: rightEar
                anchors.left: root.right
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.color;
                    ctx.beginPath();
                    ctx.moveTo(width, 0);             
                    ctx.lineTo(0, 0);                 
                    ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false);
                    ctx.fill();
                }
                Connections {
                    target: root
                    function onColorChanged() { rightEar.requestPaint() }
                }
            }
        }

        Item {
            id: detachedRecordContainer
            width: 36
            height: 36
            anchors.verticalCenter: maskContainer.verticalCenter
            anchors.right: maskContainer.left
            anchors.rightMargin: root.isRecording ? 5 : -width
            z: maskContainer.z - 1 

            Behavior on anchors.rightMargin {
                SpringAnimation { spring: 4.0; damping: 0.8; mass: 1.0 }
            }
            
            opacity: root.isRecording ? 1 : 0
            Behavior on opacity { 
                SequentialAnimation {
                    PauseAnimation { duration: root.isRecording ? 0 : 400 }
                    NumberAnimation { duration: root.isRecording ? 200 : 0 } 
                }
            }
            visible: root.isRecording || opacity > 0

            Rectangle {
                id: detachedBtnBg
                anchors.fill: parent
                radius: width / 2
                color: Colorscheme.glass_button
                visible: false 
            }

            DropShadow {
                anchors.fill: detachedBtnBg
                source: detachedBtnBg
                horizontalOffset: 0
                verticalOffset: 6
                radius: 20
                samples: 32
                color: "#80000000"
                cached: true
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Colorscheme.glass_button
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: "#ff3333"
                    antialiasing: true
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.isRecording
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isRecording = false 
                        toolsWidget.stopRecording() 
                    }
                }
            }
        }
    }
}
