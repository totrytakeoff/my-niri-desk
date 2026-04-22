import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

WidgetPanel {
    id: root

    title: "蓝牙设备"
    icon: ""
    closeAction: () => WidgetState.qsOpen = false
    Theme { id: theme }

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property bool bluetoothEnabled: false
    property int connectedCount: 0
    property int pairedCount: 0
    property bool scanRunning: false
    property string busyMac: ""
    property string busyAction: ""
    property string statusText: ""
    property bool statusError: false

    onIsActiveChanged: {
        if (isActive) {
            refreshDevices();
            refreshTimer.start();
        } else {
            refreshTimer.stop();
        }
    }

    function refreshDevices() {
        scanDevices.running = true;
    }

    function showStatus(message, isError) {
        root.statusText = message;
        root.statusError = !!isError;
        statusTimer.restart();
    }

    function recalcCounts() {
        let connected = 0;
        let paired = 0;
        for (let i = 0; i < deviceModel.count; i++) {
            const item = deviceModel.get(i);
            if (item.connected)
                connected++;
            if (item.paired)
                paired++;
        }
        root.connectedCount = connected;
        root.pairedCount = paired;
    }

    function parseDeviceLine(line) {
        const trimmed = line.trim();
        if (trimmed === "")
            return;

        if (trimmed.startsWith("__POWER__|")) {
            root.bluetoothEnabled = trimmed.substring(10) === "yes";
            return;
        }

        const parts = trimmed.split("|");
        if (parts.length < 5)
            return;

        const mac = parts[0];
        const connected = parts[1] === "yes";
        const paired = parts[2] === "yes";
        const trusted = parts[3] === "yes";
        const name = parts.slice(4).join("|");

        if (!mac || !name)
            return;

        const item = {
            mac: mac,
            name: name,
            connected: connected,
            paired: paired,
            trusted: trusted
        };

        if (connected)
            deviceModel.insert(0, item);
        else
            deviceModel.append(item);
    }

    headerTools: RowLayout {
        Theme { id: headerTheme }
        spacing: 12

        Text {
            text: "sync"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: headerTheme.subtext
            opacity: scanDevices.running ? 0.5 : 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshDevices()
            }

            RotationAnimation on rotation {
                running: scanDevices.running
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
            }
        }

        Rectangle {
            id: mainSwitch
            width: 44
            height: 24
            radius: 12
            color: root.bluetoothEnabled ? headerTheme.primary : "transparent"
            border.width: root.bluetoothEnabled ? 0 : 2
            border.color: headerTheme.outline
            Behavior on color { ColorAnimation { duration: 250 } }

            Rectangle {
                width: root.bluetoothEnabled ? 16 : 12
                height: root.bluetoothEnabled ? 16 : 12
                radius: width / 2
                x: root.bluetoothEnabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: root.bluetoothEnabled ? Colorscheme.on_primary : headerTheme.outline

                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 12
                    font.bold: true
                    color: headerTheme.primary
                    opacity: root.bluetoothEnabled ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    toggleBluetoothProc.enable = !root.bluetoothEnabled;
                    toggleBluetoothProc.running = true;
                }
            }
        }
    }

    Text {
        text: root.bluetoothEnabled ? "已配对设备" : "蓝牙已关闭"
        color: theme.subtext
        font.pixelSize: 14
        font.bold: true
        Layout.topMargin: 12
    }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
        radius: 16
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.42)
        border.width: 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: root.bluetoothEnabled ? theme.primary_container : Colorscheme.surface_container_highest

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 15
                    color: root.bluetoothEnabled ? theme.on_primary_container : theme.on_surface
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.bluetoothEnabled ? "蓝牙已开启" : "蓝牙已关闭"
                    font.bold: true
                    font.pixelSize: 14
                    color: theme.text
                }

                Text {
                    text: root.bluetoothEnabled
                        ? ("已连接 " + root.connectedCount + " 台 · 已配对 " + root.pairedCount + " 台")
                        : "打开后可快速连接已配对设备"
                    font.pixelSize: 12
                    color: root.bluetoothEnabled ? theme.primary : theme.subtext
                }

                Text {
                    text: root.scanRunning ? "正在扫描附近设备…" : "可扫描新设备并直接配对连接"
                    font.pixelSize: 11
                    color: theme.subtext
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 18
            color: root.scanRunning
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.9)
            border.width: 1
            border.color: root.scanRunning ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.28) : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.35)

            Text {
                anchors.centerIn: parent
                text: root.scanRunning ? "扫描中…" : "扫描附近设备"
                font.bold: true
                font.pixelSize: 12
                color: root.scanRunning ? theme.primary : theme.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.bluetoothEnabled && !root.scanRunning
                onClicked: {
                    discoverProc.running = true;
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.statusText !== "" ? 34 : 0
        radius: 17
        visible: root.statusText !== ""
        color: root.statusError
            ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.16)
            : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.14)
        border.width: 1
        border.color: root.statusError
            ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.24)
            : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)

        Text {
            anchors.centerIn: parent
            text: root.statusText
            font.pixelSize: 12
            font.bold: true
            color: root.statusError ? theme.error : theme.text
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 10
        model: deviceModel

        delegate: Rectangle {
            Theme { id: itemTheme }
            required property string mac
            required property string name
            required property bool connected
            required property bool paired
            required property bool trusted

            width: ListView.view.width
            height: 92
            radius: 12
            color: Qt.rgba(itemTheme.surface.r, itemTheme.surface.g, itemTheme.surface.b, 0.35)
            border.width: 1
            border.color: btMouse.containsMouse ? itemTheme.primary : itemTheme.outline
            opacity: root.bluetoothEnabled ? 1 : 0.55
            Behavior on border.color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: connected ? itemTheme.primary_container : itemTheme.surface_container_highest

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Font Awesome 7 Free Solid"
                        font.pixelSize: 14
                        color: connected ? itemTheme.on_primary_container : itemTheme.on_surface
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: name
                        font.bold: true
                        font.pixelSize: 14
                        color: itemTheme.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: connected
                            ? "已连接"
                            : (paired ? (trusted ? "已配对 · 已信任" : "已配对") : "未连接")
                        font.pixelSize: 12
                        color: connected ? itemTheme.primary : itemTheme.subtext
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: mac
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 10
                        color: itemTheme.subtext
                        visible: btMouse.containsMouse
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: paired || trusted || btMouse.containsMouse

                        Item { visible: !paired && !trusted; width: 0; height: 0 }

                        Rectangle {
                            visible: paired
                            radius: 9
                            color: Qt.rgba(itemTheme.primary.r, itemTheme.primary.g, itemTheme.primary.b, 0.14)
                            implicitWidth: 42
                            implicitHeight: 18
                            Text { anchors.centerIn: parent; text: "配对"; font.pixelSize: 10; color: itemTheme.primary; font.bold: true }
                        }

                        Rectangle {
                            visible: trusted
                            radius: 9
                            color: Qt.rgba(itemTheme.secondary.r, itemTheme.secondary.g, itemTheme.secondary.b, 0.16)
                            implicitWidth: 42
                            implicitHeight: 18
                            Text { anchors.centerIn: parent; text: "信任"; font.pixelSize: 10; color: itemTheme.secondary; font.bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: btMouse.containsMouse && !paired
                            text: "新设备"
                            font.pixelSize: 10
                            color: itemTheme.subtext
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 32
                    radius: 16
                    color: connected
                        ? itemTheme.primary
                        : (paired ? itemTheme.surface_container_highest : Qt.rgba(itemTheme.primary.r, itemTheme.primary.g, itemTheme.primary.b, 0.14))
                    border.width: connected ? 0 : 1
                    border.color: paired ? itemTheme.outline : Qt.rgba(itemTheme.primary.r, itemTheme.primary.g, itemTheme.primary.b, 0.24)
                    visible: root.bluetoothEnabled

                    Text {
                        anchors.centerIn: parent
                        text: root.busyMac === mac
                            ? root.busyAction
                            : (connected ? "断开" : (paired ? "连接" : "配对"))
                        font.bold: true
                        font.pixelSize: 12
                        color: connected ? itemTheme.on_primary : (paired ? itemTheme.on_surface : itemTheme.primary)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.busyMac === "" || root.busyMac === mac
                        onClicked: {
                            if (connected) {
                                root.busyMac = mac;
                                root.busyAction = "断开中";
                                disconnectProc.targetMac = mac;
                                disconnectProc.running = true;
                            } else if (paired) {
                                root.busyMac = mac;
                                root.busyAction = "连接中";
                                connectProc.targetMac = mac;
                                connectProc.running = true;
                            } else {
                                root.busyMac = mac;
                                root.busyAction = "配对中";
                                pairProc.targetMac = mac;
                                pairProc.running = true;
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: deviceModel.count === 0
            text: root.bluetoothEnabled ? (root.scanRunning ? "正在搜索设备…" : "未发现设备，试试先扫描附近设备") : "开启蓝牙后可查看设备"
            color: theme.subtext
            font.pixelSize: 14
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.9)

            Text {
                anchors.centerIn: parent
                text: "打开系统蓝牙设置"
                font.bold: true
                font.pixelSize: 12
                color: theme.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["gnome-control-center", "bluetooth"])
            }
        }
    }

    ListModel {
        id: deviceModel
    }

    Timer {
        id: refreshTimer
        interval: 8000
        repeat: true
        running: false
        onTriggered: root.refreshDevices()
    }

    Timer {
        id: statusTimer
        interval: 2600
        repeat: false
        onTriggered: root.statusText = ""
    }

    Process {
        id: scanDevices
        command: ["bash", "-lc", `
            BT_PWR=no
            bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && BT_PWR=yes
            echo "__POWER__|$BT_PWR"
            bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
                [ -z "$mac" ] && continue
                info=$(bluetoothctl info "$mac" 2>/dev/null)
                connected=no
                paired=no
                trusted=no
                echo "$info" | grep -q 'Connected: yes' && connected=yes
                echo "$info" | grep -q 'Paired: yes' && paired=yes
                echo "$info" | grep -q 'Trusted: yes' && trusted=yes
                printf '%s|%s|%s|%s|%s\n' "$mac" "$connected" "$paired" "$trusted" "$name"
            done
        `]
        onStarted: {
            deviceModel.clear();
            root.connectedCount = 0;
            root.pairedCount = 0;
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => root.parseDeviceLine(data)
        }
        onExited: root.recalcCounts()
    }

    Process {
        id: discoverProc
        command: ["bash", "-lc", "bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true; bluetoothctl scan off >/dev/null 2>&1 || true"]
        onStarted: {
            root.scanRunning = true;
            root.showStatus("正在扫描附近蓝牙设备", false);
        }
        onExited: {
            root.scanRunning = false;
            root.showStatus(deviceModel.count > 0 ? "扫描完成" : "扫描完成，未发现新设备", false);
            root.refreshDevices();
        }
    }

    Process {
        id: toggleBluetoothProc
        property bool enable: true
        command: ["bluetoothctl", "power", enable ? "on" : "off"]
        onExited: {
            root.showStatus(enable ? "蓝牙已开启" : "蓝牙已关闭", code !== 0);
            root.refreshDevices();
        }
    }

    Process {
        id: connectProc
        property string targetMac: ""
        command: ["bluetoothctl", "connect", targetMac]
        onExited: {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(code === 0 ? "设备已连接" : "连接失败", code !== 0);
            root.refreshDevices();
        }
    }

    Process {
        id: disconnectProc
        property string targetMac: ""
        command: ["bluetoothctl", "disconnect", targetMac]
        onExited: {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(code === 0 ? "设备已断开" : "断开失败", code !== 0);
            root.refreshDevices();
        }
    }

    Process {
        id: pairProc
        property string targetMac: ""
        command: ["bash", "-lc", "bluetoothctl pair \"" + targetMac + "\" >/dev/null 2>&1 && bluetoothctl trust \"" + targetMac + "\" >/dev/null 2>&1 && bluetoothctl connect \"" + targetMac + "\" >/dev/null 2>&1"]
        onExited: {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(code === 0 ? "配对并连接成功" : "配对或连接失败", code !== 0);
            root.refreshDevices();
        }
    }
}
