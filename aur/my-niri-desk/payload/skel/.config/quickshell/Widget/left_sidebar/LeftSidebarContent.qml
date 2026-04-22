import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Widget.common

// 左侧 sidebar 内容根容器
// ---------------------------------------------------------------------------
// 当前三页职责：
// - 总览：压缩总览与慢信息
// - 进程：轻量资源管理器
// - 会话：低频会话状态
//
// 这个文件只负责 tab 切换和内容切页，不负责各页内部逻辑。

Item {
    id: root
    Theme { id: theme }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.padding
        spacing: theme.padding

        // 顶部 tab 区。
        RowLayout {
            Layout.fillWidth: true
            
            Layout.preferredHeight: 50 
            Layout.maximumHeight: 50 
            Layout.alignment: Qt.AlignTop
            
            spacing: 15

            Repeater {
                model: [
                    { id: "dashboard", icon: "dashboard", label: "总览" },
                    { id: "processes", icon: "conversion_path", label: "进程" },
                    { id: "session", icon: "devices", label: "会话" }
                ]
                
                delegate: Item {
                    id: tabBtn
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                    
                    property bool isActive: WidgetState.leftSidebarView === modelData.id
                    property bool isHovered: hoverArea.containsMouse
                    
                    property color contentColor: isActive ? "white" : (isHovered ? "white" : "#888888")

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -4
                        spacing: 4 
                        
                        Text {
                            text: modelData.icon
                            font.family: "Material Symbols Outlined" 
                            font.pixelSize: 20 
                            color: tabBtn.contentColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        Text {
                            text: modelData.label
                            font.family: "LXGW WenKai GB Screen"
                            font.bold: tabBtn.isActive
                            font.pixelSize: 13 
                            color: tabBtn.contentColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tabBtn.isActive ? 40 : 0
                        height: 3
                        radius: 1.5
                        color: "white" 
                        opacity: tabBtn.isActive ? 1.0 : 0.0
                        
                        Behavior on width { 
                            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
                        }
                        Behavior on opacity { 
                            NumberAnimation { duration: 200 } 
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WidgetState.leftSidebarView = modelData.id
                    }
                }
            }
        }

        // 内容区：按当前 tab 显示对应页面。
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true 
            color: theme.surface
            radius: theme.radius

            InfoView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "dashboard"
            }

            SystemView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "processes"
            }

            WeatherView {
                anchors.fill: parent
                visible: WidgetState.leftSidebarView === "session"
            }
        }
    }
}
