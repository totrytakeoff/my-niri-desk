import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.Widget.common
import qs.Widget as WidgetModule

import qs.Modules.DynamicIsland.OverviewContent
import qs.Modules.DynamicIsland.Media
import qs.Modules.DynamicIsland.WallpaperContent

// 灵动岛 Hub
// ---------------------------------------------------------------------------
// 这层是灵动岛“手动展开的大面板”。
//
// 当前职责已经重新收敛成 4 页：
// - Control: 日历 + 时间 + 快控
// - Media: 媒体控制
// - Notifications: 通知中心
// - Wallpapers: 壁纸切换
//
// 它不再承担：
// - 低频系统信息展示
// - 与左侧 sidebar 重复的会话总览
// - 与右侧快捷设置重复的详细配置入口

Item {
    id: root
    signal closeRequested()
    
    property var player: null
    property int currentIndex: 0
    
    Shortcut {
        sequence: "Tab"
        onActivated: root.currentIndex = (root.currentIndex + 1) % 4
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.currentIndex = (root.currentIndex + 3) % 4
    }
    
    // 不同 tab 对应不同内容宽高，Hub 本体按当前页自适应。
    implicitWidth: currentIndex === 0 ? 860 :
                   currentIndex === 2 ? 480 :
                   currentIndex === 3 ? 960 :
                   760
    Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    
    implicitHeight: 80 + 20 + (
        currentIndex === 0 ? 520 : 
        currentIndex === 1 ? 480 : 
        currentIndex === 2 ? Math.min(620, notifCenter.totalHeight + 90) :
        300
    )
    Behavior on implicitHeight { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    // 顶部 tab 条背景。
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        radius: 22
        color: Colorscheme.glass_bar
        border.width: 1
        border.color: Colorscheme.glass_outline
    }

    RowLayout {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        // 顶部 tab 按钮：图标 + 标题 + 下划线。
        component TabBtn : Item {
            property string icon: ""
            property string title: ""
            property int index: 0
            property bool active: root.currentIndex === index
            
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: parent.parent.icon
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 20
                    color: parent.parent.active ? "white" : "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: parent.parent.title
                    font.pixelSize: 13
                    font.bold: parent.parent.active
                    color: parent.parent.active ? "white" : "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.active ? 40 : 0
                height: 3
                radius: 1.5
                color: "white" 
                opacity: parent.active ? 1.0 : 0.0
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = parent.index
            }

            HoverTag {
                open: tabMouse.containsMouse
                text: title
            }
        }

        TabBtn { icon: ""; title: "Control"; index: 0 }
        TabBtn { icon: ""; title: "Media"; index: 1 }
        TabBtn { icon: ""; title: "Notifications"; index: 2 }
        TabBtn { icon: ""; title: "Wallpapers"; index: 3 }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10 

        // Control 页：当前这套桌面里“控制中心”的核心。
        OverviewContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
            onOpenNotificationsRequested: root.currentIndex = 2
        }

        // 媒体页：播放控制和歌词等交互。
        Media {
            player: root.player
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 1
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // 通知页：复用通知中心组件，放进 Hub 内。
        WidgetModule.NotificationContent {
            id: notifCenter
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 460
            height: Math.min(parent.height, totalHeight)
            visible: root.currentIndex === 2
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // 壁纸页：切壁纸 + 触发 matugen / overview 预处理。
        WallpaperContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95 
            height: 300
            visible: root.currentIndex === 3
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onWallpaperChanged: root.closeRequested()
        }
    }
}
