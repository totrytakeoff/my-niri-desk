import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Services
import qs.config
import qs.Widget.common

Item {
    id: root

    implicitHeight: 36
    implicitWidth: layout.width + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    property string activeTitle: "Desktop"
    property string activeAppId: ""

    function updateActiveWindow() {
        let found = false;
        for (let i = 0; i < Niri.windows.count; i++) {
            const win = Niri.windows.get(i);
            if (win.isFocused) {
                activeTitle = win.title;
                activeAppId = win.appId;
                found = true;
                break;
            }
        }
        if (!found) {
            activeTitle = "Desktop";
            activeAppId = "";
        }
    }

    Connections {
        target: Niri
        function onWindowsUpdated() {
            root.updateActiveWindow();
        }
    }

    Component.onCompleted: updateActiveWindow()

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Colorscheme.glass_bar
        radius: height / 2
        visible: false
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: layout
        
        
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        
        anchors.leftMargin: 12 
        
        spacing: 10
        Item {
            id: sidebarToggle
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            scale: mouseArea.containsMouse ? 1.15 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: WidgetState.leftSidebarOpen ? "left_panel_close" : "left_panel_open"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: Colorscheme.primary
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    if (mouse.button === Qt.RightButton) {
                        const views = ["dashboard", "processes", "session"];
                        const currentIndex = views.indexOf(WidgetState.leftSidebarView);
                        WidgetState.leftSidebarView = views[(currentIndex + 1) % views.length];
                        WidgetState.leftSidebarOpen = true;
                    } else {
                        WidgetState.leftSidebarOpen = !WidgetState.leftSidebarOpen;
                    }
                }
            }

            HoverTag {
                open: mouseArea.containsMouse
                text: "Sidebar companion | Right click cycles views"
            }
        }

        // --- 2. 右侧：窗口名称 ---
        Text {
            id: windowTitle
            text: root.activeTitle
            
            font.family: "LXGW WenKai GB Screen"
            font.pointSize: 11
            color: Colorscheme.on_surface
            
            Layout.maximumWidth: 250 
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
