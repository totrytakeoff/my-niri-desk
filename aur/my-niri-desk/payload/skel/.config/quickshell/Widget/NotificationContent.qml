import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Widget.common
import "./notification" 

// 通知中心主容器
// ---------------------------------------------------------------------------
// 这层是通知系统的总入口。
//
// 它维护 3 个内部视图：
// - main: 按应用分组
// - detail: 某一个应用的通知详情
// - all: 所有通知长列表
//
// 当前重要行为：
// - 关闭时会强制重置回 main/compact
// - detail 页右下角已经改成直接“返回总览”，不再弹二级菜单

Item {
    id: root
    Theme { id: theme }

    // 当前激活视图的高度，用来驱动整个通知面板自适应。
    readonly property int activeViewHeight: currentViewItem ? currentViewItem.totalHeight : 80
    readonly property int totalHeight: activeViewHeight + 40 + theme.padding * 2
    
    property var allMessages: WidgetState.getAllMessages()
    property bool hasMessages: allMessages.length > 0

    // 通知数据变化时，三个子视图都同步刷新。
    Connections { 
        target: WidgetState;
        function onNotifDataChanged() { 
            root.allMessages = WidgetState.getAllMessages();
            mainView.update(); detailView.update();
            allView.update(); 
        } 
    }
    
    property var currentViewItem: stackLayout.children[stackLayout.currentIndex]

    // 顶部标题与操作区。
    Item {
        id: headerArea
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: theme.padding; anchors.leftMargin: theme.padding; anchors.rightMargin: theme.padding
        height: 32

        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: WidgetState.notifCurrentView === "detail" ? "应用详情" : "通知中心"
            font.bold: true; font.pixelSize: 16; color: theme.text
        }

        RowLayout {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // 清空通知按钮：逐条调用 WidgetState.dismissMessage。
            Rectangle {
                width: 32; height: 32; radius: 16
                color: trashHover.containsMouse && root.hasMessages ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.15) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8" 
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                    color: root.hasMessages ? theme.error : theme.subtext
                    opacity: root.hasMessages ? 1.0 : 0.4
                }

                MouseArea {
                    id: trashHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: root.hasMessages ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.hasMessages) {
                            var msgs = WidgetState.getAllMessages();
                            for (var i = 0; i < msgs.length; i++) {
                                WidgetState.dismissMessage(msgs[i].appId, msgs[i].id);
                            }
                        }
                    }
                }
            }

            // compact/all 切换按钮；detail 视图下不显示。
            Rectangle {
                width: 32; height: 32; radius: 16
                color: modeHover.containsMouse ? Colorscheme.surface_container_high : "transparent"
                visible: WidgetState.notifCurrentView !== "detail" 

                Text {
                    anchors.centerIn: parent
                    text: WidgetState.notifDisplayMode === "compact" ? "\uf0ca" : "\uf009" 
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14; color: theme.text
                }

                MouseArea {
                    id: modeHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { WidgetState.notifDisplayMode = WidgetState.notifDisplayMode === "compact" ? "all" : "compact"; }
                }
            }

            // 关闭按钮：关闭通知面板前先恢复主视图，避免残留 detail 状态。
            Rectangle {
                width: 32; height: 32; radius: 16
                color: closeHover.containsMouse ? Colorscheme.surface_container_high : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d" 
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 16; color: theme.text
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WidgetState.notifCurrentView = "main";
                        WidgetState.notifDisplayMode = "compact";
                        WidgetState.notifDetailAppId = "";
                        WidgetState.notifOpen = false;
                        WidgetState.notifPinned = false; 
                    }
                }
            }
        }
    }

    // 三层内部视图切换。
    StackLayout {
        id: stackLayout
        anchors.top: headerArea.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: theme.padding
        anchors.topMargin: 12 
        
        currentIndex: {
            if (WidgetState.notifCurrentView === "detail") return 1;
            if (WidgetState.notifDisplayMode === "all") return 2;    
            return 0;                                                
        }

        NotifMainView { id: mainView; Layout.fillWidth: true; Layout.fillHeight: true }
        NotifDetailView { id: detailView; Layout.fillWidth: true; Layout.fillHeight: true; appId: WidgetState.notifDetailAppId }
        NotifAllView { id: allView; Layout.fillWidth: true; Layout.fillHeight: true } 
    }
}
