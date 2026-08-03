// Modules/HotCorner/HotCornerDetectorWindow.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.Services

PanelWindow {
    id: root
    screen: Niri.focusedScreen
    
    WlrLayershell.layer: WlrLayer.Top 
    WlrLayershell.namespace: "qs-hotcorner-bottom-right"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors { right: true; bottom: true }
    
    // 【修改】：10x10 像素，隐形且更容易触发
    implicitWidth: 10
    implicitHeight: 10
    color: "transparent"

    // ============================================================
    // 【新增】：防误触 1 秒延迟逻辑
    // ============================================================
    Timer {
        id: openTimer
        interval: 1000 // 悬浮 1 秒钟打开
        onTriggered: WidgetState.openNotifPanelFromHotCorner()
    }

    Timer {
        id: closeTimer
        interval: 1000 // 移开 1 秒钟关闭
        onTriggered: {
            // 如果鼠标此时没有移动到通知面板上，才真正关闭
            if (WidgetState.hotCornerEnabled
                    && !WidgetState.notifIsHovered
                    && !WidgetState.notifPinned) {
                WidgetState.notifOpen = false;
            }
        }
    }

    Connections {
        target: WidgetState
        function onHotCornerEnabledChanged() {
            if (!WidgetState.hotCornerEnabled) {
                openTimer.stop()
                closeTimer.stop()
            }
        }
    }

    MouseArea {
        id: hotCornerDetector
        anchors.fill: parent
        hoverEnabled: true 
        
        onEntered: {
            if (!WidgetState.hotCornerEnabled) return;
            closeTimer.stop();
            openTimer.start();
        }
        onExited: {
            openTimer.stop();
            if (WidgetState.hotCornerEnabled && !WidgetState.notifPinned) {
                closeTimer.start();
            }
        }
    }
}
