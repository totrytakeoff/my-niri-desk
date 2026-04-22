import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

Item {
    id: root
    Theme { id: theme }

    property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "session"

    property string desktopName: "unknown"
    property string wifiState: "Loading..."
    property string ethernetState: "Loading..."
    property string bluetoothState: "Loading..."
    property string audioOutput: "Loading..."
    property string powerProfile: "Loading..."
    property string batteryText: "Detecting..."

    function refresh() {
        if (!snapshotProc.running) snapshotProc.running = true;
    }

    component StatusCard : Rectangle {
        property string icon: ""
        property string title: ""
        property string valueText: ""
        property color accent: theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: 16
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: icon
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                    color: accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: title
                    font.pixelSize: 11
                    color: theme.subtext
                }

                Text {
                    text: valueText
                    font.pixelSize: 13
                    font.bold: true
                    color: theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    component SessionPill : Rectangle {
        property string title: ""
        property string valueText: ""
        property color accent: theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 16
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.18)
        border.width: 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.22)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            Text {
                text: title
                font.pixelSize: 10
                color: theme.subtext
            }

            Text {
                text: valueText
                font.pixelSize: 15
                font.bold: true
                color: accent
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    onIsForegroundChanged: {
        if (isForeground) refresh();
    }

    Timer {
        interval: 10000
        running: root.isForeground
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: snapshotProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/session_snapshot.py"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const d = JSON.parse(data.trim());
                    root.desktopName = d.desktop || "unknown";
                    root.wifiState = d.wifi.state === "connected" ? d.wifi.name : ("Wi-Fi " + d.wifi.state);
                    root.ethernetState = d.ethernet.device !== ""
                        ? (d.ethernet.state === "connected" ? (d.ethernet.name || d.ethernet.device) : d.ethernet.device + " · " + d.ethernet.state)
                        : "No wired interface";
                    root.bluetoothState = d.bluetooth.powered
                        ? (d.bluetooth.connected_count > 0 ? d.bluetooth.connected_count + " device(s) connected" : "Powered on")
                        : "Powered off";
                    root.audioOutput = d.audio_output || "Unknown output";
                    root.powerProfile = d.power_profile || "unknown";
                    root.batteryText = d.battery.present
                        ? (d.battery.percent + " · " + d.battery.state)
                        : "No battery";
                } catch (e) {}
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: headerRow.implicitHeight + 32
                implicitHeight: headerRow.implicitHeight + 32
                radius: 18
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "会话"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 24
                            font.bold: true
                            color: theme.text
                        }

                        Text {
                            text: "查看桌面、网络、电源与默认设备的低频状态。"
                            font.pixelSize: 12
                            color: theme.subtext
                        }
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.14)

                        Text {
                            anchors.centerIn: parent
                            text: "refresh"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: Colorscheme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SessionPill { title: "桌面"; valueText: root.desktopName; accent: "#8ab4f8" }
                SessionPill { title: "电源"; valueText: root.powerProfile; accent: "#81c995" }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                StatusCard {
                    icon: "wifi"
                    title: "无线网络"
                    valueText: root.wifiState
                    accent: "#8ab4f8"
                }

                StatusCard {
                    icon: "settings_ethernet"
                    title: "有线网络"
                    valueText: root.ethernetState
                    accent: "#81c995"
                }

                StatusCard {
                    icon: "bluetooth"
                    title: "蓝牙"
                    valueText: root.bluetoothState
                    accent: "#cba6f7"
                }

                StatusCard {
                    icon: "battery_full_alt"
                    title: "电池"
                    valueText: root.batteryText
                    accent: "#cba6f7"
                }

                StatusCard {
                    icon: "speaker"
                    title: "默认输出"
                    valueText: root.audioOutput
                    accent: "#fcad70"
                    Layout.columnSpan: 2
                }
            }
        }
    }
}
