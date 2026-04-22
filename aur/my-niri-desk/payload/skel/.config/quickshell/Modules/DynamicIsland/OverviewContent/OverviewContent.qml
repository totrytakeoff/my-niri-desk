import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell
import qs.config
import qs.Services

// 灵动岛 Control 页
// ---------------------------------------------------------------------------
// 当前布局已经定成：
// - 上：大时间
// - 下左：日历
// - 下右：Quick Controls + 竖向 slider
//
// 这里是“控制中心”的主视图，不再承担：
// - 重复通知列表
// - 低频系统信息大卡片
// - sidebar 风格的常驻信息展示

Item {
    id: root
    signal closeRequested() 
    signal openNotificationsRequested()

    implicitWidth: 860 
    implicitHeight: 520 

    property int activeSliderIndex: 0 
    property var recentNotifications: []
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function refreshRecentNotifications() {
        const all = WidgetState.getAllMessages();
        recentNotifications = all.slice(0, 3);
    }

    Component.onCompleted: refreshRecentNotifications()
    Connections {
        target: WidgetState
        function onNotifDataChanged() {
            root.refreshRecentNotifications();
        }
    }

    // 共享玻璃卡组件。
    // showFrame=false 时，允许某些内容（比如时间）只保留文字，不叠额外背景。
    component SolidGlassCard : Item {
        id: cardRoot
        property bool showFrame: true
        default property alias content: innerContainer.data

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: cardRoot.showFrame ? Colorscheme.glass_card : "transparent"
            border.width: cardRoot.showFrame ? 1 : 0
            border.color: Colorscheme.glass_outline
        }
        Item { id: innerContainer; anchors.fill: parent; anchors.margins: 16 }
    }

    // Control 页右侧那 3 个竖向滑杆组件。
    // 现在已经改成默认展开的“粗胶囊拖条”版本。
    component ExpandableVertSlider : Item {
        id: sliderCol
        property int sliderIndex: 0 
        property string icon: ""
        property real sliderValue: 0.5
        property bool expanded: true
        signal sliderMoved(real val)

        property real expandProgress: expanded ? 1.0 : 0.0
        Behavior on expandProgress { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        property int expandedTrackHeight: 110

        width: 52
        implicitHeight: 48 + 10 + (expandedTrackHeight * expandProgress)

        Rectangle {
            width: 48; height: 48; radius: 24
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.alpha(Colorscheme.primary_container, 0.72)
            border.width: 1
            border.color: Qt.alpha(Colorscheme.primary, 0.24)
            Behavior on color { ColorAnimation { duration: 250 } }
            Text {
                anchors.centerIn: parent; text: sliderCol.icon; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 18
                color: Colorscheme.on_surface
            }
        }

        Item {
            y: 58
            width: 48
            height: sliderCol.expandedTrackHeight * sliderCol.expandProgress
            opacity: sliderCol.expandProgress
            
            Item {
                anchors.centerIn: parent
                width: 32  // 拖条边框胶囊宽度
                height: parent.height - 2
                clip: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(Colorscheme.inverse_surface.red, Colorscheme.inverse_surface.green, Colorscheme.inverse_surface.blue, 0.18)
                    border.width: 1
                    border.color: Qt.alpha(Colorscheme.inverse_surface, 0.16)
                    Rectangle {
                        x: parent.width / 2 - width / 2
                        y: 5
                        width: 30  //拖条胶囊宽度
                        height: parent.height - 10
                        radius: width / 2
                        color: Qt.rgba(Colorscheme.inverse_surface.red, Colorscheme.inverse_surface.green, Colorscheme.inverse_surface.blue, 0.08)
                        Rectangle {
                            width: parent.width
                            height: (1.0 - vSlider.visualPosition) * parent.height
                            y: vSlider.visualPosition * parent.height
                            radius: width / 2
                            color: Colorscheme.primary
                        }
                    }
                }
            }

            Slider {
                id: vSlider
                orientation: Qt.Vertical; anchors.fill: parent; anchors.margins: 4
                value: sliderCol.sliderValue; hoverEnabled: true; background: Item {} 
                onMoved: sliderCol.sliderMoved(value)

                handle: Rectangle { //拖条手柄
                    x: vSlider.leftPadding + vSlider.availableWidth / 2 - width / 2
                    y: vSlider.topPadding + vSlider.visualPosition * (vSlider.availableHeight - height)
                    width: 30
                    height: 30
                    radius: 15
                    color: Colorscheme.primary_fixed
                    border.width: 2
                    border.color: Qt.alpha(Colorscheme.primary, 0.85)
                    Item {
                        anchors.left: parent.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42
                        height: 28
                        visible: vSlider.pressed || vSlider.hovered
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Qt.alpha(Colorscheme.primary_container, 0.90)
                            border.width: 1
                            border.color: Qt.alpha(Colorscheme.primary, 0.30)
                        }
                        Rectangle { 
                            width: 10
                            height: 10
                            radius: 2
                            color: Qt.alpha(Colorscheme.primary_container, 0.90)
                            rotation: 45
                            anchors.left: parent.left
                            anchors.leftMargin: -3
                            anchors.verticalCenter: parent.verticalCenter
                            z: -1
                        }
                        Text { 
                            anchors.centerIn: parent; text: Math.round(vSlider.value * 100); color: Colorscheme.on_primary_container
                            font.pixelSize: 14; font.bold: true; font.family: "JetBrains Mono Nerd Font" 
                        }
                    }
                }
            }
        }
    }

    // Control 页主布局。
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32 
        spacing: 16

        // 顶部大时间区：现在只保留文字，不再叠额外背景框。
        SolidGlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            showFrame: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 2
                anchors.topMargin: -80
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                anchors.bottomMargin: 0
                
                Text {
                    text: Qt.formatDateTime(root.now, "hh:mm")
                    font.pixelSize: 80
                    font.bold: true
                    color: Colorscheme.on_surface
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: Qt.formatDateTime(root.now, "yyyy年M月d日 dddd")
                    font.pixelSize: 20
                    color: Colorscheme.on_surface_variant
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // 下半区：左日历，右 quick controls。
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // 日历外层卡。CalendarWidget 本体已去掉自己的重复背景。
            SolidGlassCard {
                Layout.preferredWidth: 280
                Layout.minimumWidth: 280
                Layout.maximumWidth: 280
                Layout.fillHeight: true
                CalendarWidget { anchors.fill: parent }
            }

            // 右侧 quick controls 卡。
            SolidGlassCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 18

        

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Text {
                            text: "Quick Controls"
                            font.pixelSize: 15
                            font.bold: true
                            color: Colorscheme.on_surface
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 16

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    ControlCenterWidget {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.horizontalCenterOffset: -18
                                        anchors.verticalCenterOffset: +22
                                    }
                                }

                                RowLayout {
                                    Layout.preferredWidth: 176
                                    Layout.minimumWidth: 176
                                    Layout.maximumWidth: 176
                                    Layout.fillHeight: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 12

                                    ExpandableVertSlider { sliderIndex: 0; icon: ""; expanded: true; sliderValue: Volume.sinkVolume; onSliderMoved: (val) => Volume.setSinkVolume(val) }
                                    ExpandableVertSlider { sliderIndex: 1; icon: ""; expanded: true; sliderValue: Volume.sourceVolume; onSliderMoved: (val) => Volume.setSourceVolume(val) }
                                    ExpandableVertSlider { sliderIndex: 2; icon: ""; expanded: true; sliderValue: ControlBackend.brightnessValue; onSliderMoved: (val) => ControlBackend.setBrightness(val) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
