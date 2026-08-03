import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services as Services
import qs.Widget.common
import qs.config

WidgetPanel {
    id: root

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"

    function deviceIcon(iconName) {
        const icon = (iconName || "").toLowerCase();
        if (icon.includes("headset") || icon.includes("headphone") || icon.includes("audio"))
            return "headphones";

        if (icon.includes("keyboard"))
            return "keyboard";

        if (icon.includes("mouse"))
            return "mouse";

        if (icon.includes("phone") || icon.includes("smartphone"))
            return "smartphone";

        if (icon.includes("computer"))
            return "computer";

        return "bluetooth";
    }

    function deviceSubtitle(connected, paired, trusted) {
        if (connected)
            return "已连接";

        if (paired && trusted)
            return "已配对 · 已信任";

        if (paired)
            return "已配对";

        return "可配对";
    }

    function performDeviceAction(mac, connected, paired) {
        if (connected)
            Services.Bluetooth.disconnectDevice(mac);
        else if (paired)
            Services.Bluetooth.connectDevice(mac);
        else
            Services.Bluetooth.pairDevice(mac);
    }

    title: "蓝牙设备"
    icon: ""
    closeAction: () => {
        return WidgetState.qsOpen = false;
    }
    onIsActiveChanged: {
        if (isActive)
            Services.Bluetooth.refresh();

    }

    Theme {
        id: theme
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: {
                if (Services.Bluetooth.powerBusy)
                    return Services.Bluetooth.powered ? "正在关闭蓝牙…" : "正在开启蓝牙…";

                if (!Services.Bluetooth.powered)
                    return "蓝牙已关闭";

                return "蓝牙已开启 · " + Services.Bluetooth.connectedCount + " 台已连接 · " + Services.Bluetooth.pairedCount + " 台已配对";
            }
            color: Services.Bluetooth.connectedCount > 0 ? theme.primary : theme.subtext
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            id: scanButton

            Layout.preferredWidth: scanContent.implicitWidth + 20
            Layout.preferredHeight: 30
            radius: 15
            visible: Services.Bluetooth.powered
            color: scanMouse.containsMouse || Services.Bluetooth.scanning ? theme.glass_card_hover : "transparent"
            border.width: Services.Bluetooth.scanning ? 1 : 0
            border.color: Qt.alpha(theme.primary, 0.35)
            opacity: Services.Bluetooth.busyMac === "" && !Services.Bluetooth.powerBusy ? 1 : 0.5

            RowLayout {
                id: scanContent

                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "sync"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Services.Bluetooth.scanning ? theme.primary : theme.subtext

                    RotationAnimation on rotation {
                        running: Services.Bluetooth.scanning
                        from: 0
                        to: 360
                        loops: Animation.Infinite
                        duration: 900
                    }

                }

                Text {
                    text: Services.Bluetooth.scanning ? "扫描中" : "扫描附近设备"
                    color: Services.Bluetooth.scanning ? theme.primary : theme.text
                    font.pixelSize: 11
                    font.bold: true
                }

            }

            MouseArea {
                id: scanMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !Services.Bluetooth.scanning && !Services.Bluetooth.powerBusy && Services.Bluetooth.busyMac === ""
                onClicked: Services.Bluetooth.scan()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: deviceList

            anchors.fill: parent
            clip: true
            spacing: 4
            model: Services.Bluetooth.devices
            visible: Services.Bluetooth.powered
            section.property: "group"
            section.criteria: ViewSection.FullString

            section.delegate: Item {
                required property string section

                width: ListView.view.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.section
                    color: theme.subtext
                    font.pixelSize: 13
                    font.bold: true
                }

            }

            delegate: Rectangle {
                id: deviceRow

                required property string mac
                required property string name
                required property string iconName
                required property string group
                required property bool connected
                required property bool paired
                required property bool trusted
                property bool busy: Services.Bluetooth.busyMac === mac
                property bool highlighted: rowHover.hovered || busy

                width: ListView.view.width
                height: 70
                radius: 12
                color: highlighted ? theme.glass_card_subtle : "transparent"
                border.width: 1
                border.color: highlighted ? (busy ? theme.primary : Qt.alpha(theme.primary, 0.48)) : "transparent"

                HoverHandler {
                    id: rowHover
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 28
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.deviceIcon(deviceRow.iconName)
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 23
                        color: deviceRow.connected ? theme.primary : theme.subtext
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: deviceRow.name
                            color: deviceRow.connected ? theme.primary : theme.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.deviceSubtitle(deviceRow.connected, deviceRow.paired, deviceRow.trusted)
                            color: deviceRow.connected ? theme.primary : theme.subtext
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                    }

                    Rectangle {
                        id: actionButton

                        property bool shouldShow: rowHover.hovered || deviceRow.connected || deviceRow.busy

                        Layout.preferredWidth: shouldShow ? 76 : 0
                        Layout.preferredHeight: 30
                        radius: 15
                        visible: Layout.preferredWidth > 0
                        opacity: shouldShow ? 1 : 0
                        color: deviceRow.connected ? theme.primary : (deviceRow.busy ? Qt.alpha(theme.primary, 0.16) : theme.glass_card_hover)
                        border.width: deviceRow.connected ? 0 : 1
                        border.color: deviceRow.busy ? Qt.alpha(theme.primary, 0.4) : theme.glass_outline_soft

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                visible: deviceRow.busy
                                text: "sync"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: theme.primary

                                RotationAnimation on rotation {
                                    running: deviceRow.busy
                                    from: 0
                                    to: 360
                                    loops: Animation.Infinite
                                    duration: 800
                                }

                            }

                            Text {
                                text: deviceRow.busy ? Services.Bluetooth.busyAction : (deviceRow.connected ? "断开" : (deviceRow.paired ? "连接" : "配对"))
                                color: deviceRow.connected ? theme.on_primary : (deviceRow.busy ? theme.primary : theme.text)
                                font.pixelSize: 11
                                font.bold: true
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Services.Bluetooth.busyMac === "" && !Services.Bluetooth.scanning && !Services.Bluetooth.powerBusy
                            onClicked: root.performDeviceAction(deviceRow.mac, deviceRow.connected, deviceRow.paired)
                        }

                        Behavior on Layout.preferredWidth {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: !Services.Bluetooth.powered

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "bluetooth_disabled"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 32
                color: theme.subtext
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "蓝牙已关闭"
                color: theme.text
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "使用标题栏开关开启蓝牙"
                color: theme.subtext
                font.pixelSize: 11
            }

        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: Services.Bluetooth.powered && Services.Bluetooth.devices.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Bluetooth.scanning ? "radar" : "bluetooth_searching"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 32
                color: theme.subtext
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Bluetooth.scanning ? "正在搜索附近设备…" : "暂无蓝牙设备"
                color: theme.subtext
                font.pixelSize: 13
            }

        }

        Rectangle {
            id: statusToast

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: Math.min(parent.width - 24, toastText.implicitWidth + 32)
            height: 36
            radius: 18
            visible: Services.Bluetooth.statusText !== ""
            color: Services.Bluetooth.statusError ? Qt.alpha(theme.error, 0.18) : Qt.alpha(theme.background, 0.88)
            border.width: 1
            border.color: Services.Bluetooth.statusError ? Qt.alpha(theme.error, 0.34) : theme.glass_outline_soft
            z: 20

            Text {
                id: toastText

                anchors.centerIn: parent
                text: Services.Bluetooth.statusText
                color: Services.Bluetooth.statusError ? theme.error : theme.text
                font.pixelSize: 11
                font.bold: true
            }

        }

    }

    headerTools: RowLayout {
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: settingsMouse.containsMouse ? theme.glass_card_hover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "settings"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 19
                color: theme.subtext
            }

            MouseArea {
                id: settingsMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["desk-app-run", "--", "gnome-control-center", "bluetooth"])
            }

        }

        Rectangle {
            id: mainSwitch

            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            radius: 12
            enabled: !Services.Bluetooth.powerBusy && !Services.Bluetooth.scanning && Services.Bluetooth.busyMac === ""
            opacity: enabled ? 1 : 0.58
            color: Services.Bluetooth.powered ? theme.primary : "transparent"
            border.width: Services.Bluetooth.powered ? 0 : 2
            border.color: theme.outline

            Rectangle {
                visible: !Services.Bluetooth.powerBusy
                width: Services.Bluetooth.powered ? 16 : 12
                height: width
                radius: width / 2
                x: Services.Bluetooth.powered ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Bluetooth.powered ? Colorscheme.on_primary : theme.outline

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 12
                    font.bold: true
                    color: theme.primary
                    opacity: Services.Bluetooth.powered ? 1 : 0
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: 260
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                visible: Services.Bluetooth.powerBusy
                text: "sync"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: Services.Bluetooth.powered ? theme.on_primary : theme.subtext

                RotationAnimation on rotation {
                    running: Services.Bluetooth.powerBusy
                    from: 0
                    to: 360
                    loops: Animation.Infinite
                    duration: 800
                }

            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: mainSwitch.enabled
                onClicked: Services.Bluetooth.togglePower()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 220
                }

            }

        }

    }

}
