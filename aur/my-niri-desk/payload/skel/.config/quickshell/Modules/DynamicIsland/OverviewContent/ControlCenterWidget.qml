import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.Modules.DynamicIsland.OverviewContent 
import qs.Widget.common

Item {
    id: root
    implicitWidth: 272
    implicitHeight: 236

    // ============================================================
    // 【组件库】
    // ============================================================
    component MiniCircleBtn : Item {
        property string icon: ""
        property string tip: ""
        property bool active: false
        property color activeColor: Colorscheme.primary
        property color inactiveColor: Colorscheme.glass_button
        property color iconActiveColor: Colorscheme.on_primary
        property color iconInactiveColor: Colorscheme.on_surface
        
        signal clicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 48

        Rectangle {
            anchors.fill: parent
            radius: width / 2 
            color: active ? activeColor : inactiveColor
            Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
            scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

            Text { 
                anchors.centerIn: parent
                text: icon
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 16
                color: active ? iconActiveColor : iconInactiveColor 
            }

            MouseArea { 
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor 
                onClicked: parent.parent.clicked() 
            }
        }

        HoverTag {
            open: btnArea.containsMouse
            text: tip
        }
    }

    component ShapeShiftTile : Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string tip: ""
        property string subtitle: ""
        property bool active: false
        
        signal clicked()

        Layout.preferredWidth: 112
        Layout.preferredHeight: 48
        
        radius: active ? 12 : height / 2
        Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
        
        color: active
            ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.18)
            : Colorscheme.glass_button
        border.width: 1
        border.color: active ? Qt.alpha(Colorscheme.primary, 0.24) : Colorscheme.glass_outline
        Behavior on color { ColorAnimation { duration: 250 } }
        
        scale: tileArea.pressed ? 0.94 : (tileArea.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Rectangle {
            id: innerBlock
            width: 32
            height: 32
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            radius: tile.active ? 10 : width / 2
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
            color: tile.active ? Colorscheme.primary : Qt.alpha(Colorscheme.on_surface_variant, 0.18)
            Behavior on color { ColorAnimation { duration: 250 } }
            
            Text { 
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Colorscheme.on_primary : Colorscheme.on_surface
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 14 
            }
        }

        ColumnLayout {
            anchors.left: innerBlock.right
            anchors.leftMargin: 10
            anchors.right: parent.right      // 【新增】：强行规定右侧边界
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text { 
                text: tile.title
                font.pixelSize: 13
                font.bold: true
                color: Colorscheme.on_surface 
                Layout.fillWidth: true       // 【新增】：填满剩余空间
                elide: Text.ElideRight       // 【新增】：超出自动变成省略号
            }
            Text { 
                text: tile.subtitle
                font.pixelSize: 10
                opacity: 0.8
                color: Colorscheme.on_surface
                visible: tile.subtitle !== "" 
                Layout.fillWidth: true       // 【新增】：填满剩余空间
                elide: Text.ElideRight       // 【新增】：超出自动变成省略号
            }
        }

        MouseArea { 
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked() 
        }

        HoverTag {
            open: tileArea.containsMouse
            text: tip !== "" ? tip : title
        }
    }

    component CornerBtn : Rectangle {
        property string icon: ""
        property string tip: ""
        property color bgColor: "transparent"
        property color fgColor: "white"

        signal clicked()

        width: 48
        height: 48
        radius: 14 
        color: bgColor
        
        scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: fgColor 
            font.family: "Font Awesome 7 Free Solid"
            font.pixelSize: 18
        }

        MouseArea { 
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor 
            onClicked: parent.parent.clicked()
        }

        HoverTag {
            open: btnArea.containsMouse
            text: tip
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        GridLayout {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            columns: 4
            rowSpacing: 12
            columnSpacing: 16

            ShapeShiftTile { 
                Layout.row: 0
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignHCenter
                icon: ""
                title: "Wi-Fi"
                tip: "Toggle Wi-Fi power"
                active: ControlBackend.wifiEnabled 
                subtitle: ControlBackend.wifiEnabled ? "已连接" : "已断开"
                onClicked: ControlBackend.toggleWifi()
            }

            ShapeShiftTile { 
                Layout.row: 0
                Layout.column: 2
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignHCenter
                icon: ""
                title: "蓝牙"
                tip: "Toggle Bluetooth power"
                active: ControlBackend.bluetoothEnabled 
                subtitle: !ControlBackend.bluetoothEnabled ? "已关闭" : (ControlBackend.bluetoothConnected ? "已连接" : "已开启")
                onClicked: ControlBackend.toggleBluetooth()
            }

            Rectangle {
                id: powerBar
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 3 
                Layout.preferredWidth: 176
                Layout.preferredHeight: 48
                radius: 24
                
                color: Colorscheme.glass_card
                border.width: 1
                border.color: Colorscheme.glass_outline
                
                property int currentIndex: 1
                property var modes: ["", "", ""]
                
                Rectangle {
                    id: indicator
                    width: 40
                    height: 40
                    radius: 20
                    color: Colorscheme.primary
                    y: 4 
                    property real segmentWidth: powerBar.width / 3
                    x: (powerBar.currentIndex * segmentWidth) + ((segmentWidth - width) / 2)
                    Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: powerBar.modes.length
                        Item {
                            width: powerBar.width / 3
                            height: powerBar.height
                            Text { 
                                anchors.centerIn: parent
                                text: powerBar.modes[index]
                                font.family: "Font Awesome 7 Free Solid"
                                font.pixelSize: 16
                                color: powerBar.currentIndex === index ? Colorscheme.on_primary : Colorscheme.on_surface
                                Behavior on color { ColorAnimation { duration: 300 } } 
                            }
                            MouseArea { 
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor 
                                onClicked: {
                                    powerBar.currentIndex = index;
                                    let mode = index === 0 ? "power-saver" : (index === 1 ? "balanced" : "performance");
                                    Quickshell.execDetached(["powerprofilesctl", "set", mode]);
                                }
                            }
                        }
                    }
                }
            }

            MiniCircleBtn { 
                Layout.row: 1
                Layout.column: 3
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter 
                icon: ""
                tip: "Toggle dark mode"
                property bool isDark: true
                active: isDark
                onClicked: {
                    isDark = !isDark;
                    let scheme = isDark ? "prefer-dark" : "default";
                    Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme]);
                }
            } 

            MiniCircleBtn { 
                Layout.row: 2
                Layout.column: 0
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                icon: ""
                tip: "Toggle Do Not Disturb"
                active: ControlBackend.dndEnabled
                onClicked: ControlBackend.toggleDnd()
            } 

            MiniCircleBtn { 
                Layout.row: 2
                Layout.column: 1
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                icon: ""
                tip: "Toggle caffeine mode"
                active: ControlBackend.caffeineEnabled
                onClicked: ControlBackend.toggleCaffeine()
            } 

            CornerBtn { 
                Layout.row: 2
                Layout.column: 2
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                icon: ""
                tip: "Settings placeholder"
                bgColor: Qt.alpha(Colorscheme.tertiary_container, 0.80)
                fgColor: Colorscheme.on_tertiary_container 
                onClicked: console.log("等待后续开发：控制面板")
            }

            CornerBtn { 
                Layout.row: 2
                Layout.column: 3
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                icon: ""
                tip: "Open power menu"
                bgColor: Qt.alpha(Colorscheme.error_container, 0.78)
                fgColor: Colorscheme.on_error_container
                onClicked: Quickshell.execDetached(["wlogout", "-p", "layer-shell", "-b", "2"])
            }
        }
    }
}
