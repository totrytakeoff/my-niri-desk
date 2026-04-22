import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

Item {
    id: root
    Theme { id: theme }

    property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "dashboard"

    property real cpuValue: 0
    property real ramValue: 0
    property real diskValue: 0
    property real tempValue: 0

    property string cpuText: "--"
    property string ramText: "--"
    property string diskText: "--"
    property string tempText: "--"
    property string chassisText: "Loading..."
    property string uptimeText: "Loading..."
    property string osAgeText: "Loading..."

    component CompactMetric : Rectangle {
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property real ratio: 0
        property color accent: theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 88
        radius: 16
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)

                    Text {
                        anchors.centerIn: parent
                        text: icon
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: label
                        font.pixelSize: 11
                        color: theme.subtext
                    }
                    Text {
                        text: valueText
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 17
                        font.bold: true
                        color: theme.text
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)

                Rectangle {
                    width: Math.max(8, parent.width * Math.max(0, Math.min(1, ratio)))
                    height: parent.height
                    radius: parent.radius
                    color: accent
                }
            }
        }
    }

    component DetailChip : Rectangle {
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property color accent: theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: icon
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: label
                    font.pixelSize: 10
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

    component SummaryPill : Rectangle {
        property string title: ""
        property string valueText: ""
        property color accent: theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 56
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
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 16
                font.bold: true
                color: accent
            }
        }
    }

    onIsForegroundChanged: {
        if (isForeground) {
            if (!monitorProc.running) monitorProc.running = true;
            if (!detailsProc.running) detailsProc.running = true;
        }
    }

    Timer {
        interval: 5000
        running: root.isForeground
        repeat: true
        onTriggered: {
            if (!monitorProc.running) monitorProc.running = true;
        }
    }

    Timer {
        interval: 30000
        running: root.isForeground
        repeat: true
        onTriggered: {
            if (!detailsProc.running) detailsProc.running = true;
        }
    }

    Process {
        id: monitorProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_monitor.py"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const d = JSON.parse(data.trim());
                    root.cpuValue = d.cpu.value;
                    root.ramValue = d.ram.value;
                    root.diskValue = d.disk.value;
                    root.tempValue = d.temp.value;
                    root.cpuText = d.cpu.text;
                    root.ramText = d.ram.text;
                    root.diskText = d.disk.text;
                    root.tempText = d.temp.text;
                } catch (e) {}
            }
        }
    }

    Process {
        id: detailsProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_details.py"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const d = JSON.parse(data.trim());
                    root.chassisText = d.chassis || root.chassisText;
                    root.uptimeText = d.uptime || root.uptimeText;
                    root.osAgeText = d.os_age || root.osAgeText;
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
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "总览"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 22
                            font.bold: true
                            color: theme.text
                        }

                        Text {
                            text: Qt.formatDateTime(new Date(), "dddd, dd MMM yyyy")
                            font.pixelSize: 12
                            color: theme.subtext
                        }

                        Text {
                            text: root.chassisText
                            font.pixelSize: 12
                            color: theme.subtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
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
                            onClicked: {
                                if (!monitorProc.running) monitorProc.running = true;
                                if (!detailsProc.running) detailsProc.running = true;
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SummaryPill { title: "CPU"; valueText: root.cpuText; accent: "#8ab4f8" }
                SummaryPill { title: "内存"; valueText: root.ramText; accent: "#cba6f7" }
                SummaryPill { title: "温度"; valueText: root.tempText; accent: "#81c995" }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                CompactMetric {
                    icon: "neurology"
                    label: "CPU"
                    valueText: root.cpuText
                    ratio: root.cpuValue
                    accent: "#8ab4f8"
                }

                CompactMetric {
                    icon: "memory"
                    label: "内存"
                    valueText: root.ramText
                    ratio: root.ramValue
                    accent: "#cba6f7"
                }

                CompactMetric {
                    icon: "hard_disk"
                    label: "磁盘"
                    valueText: root.diskText
                    ratio: root.diskValue
                    accent: "#81c995"
                }

                CompactMetric {
                    icon: "device_thermostat"
                    label: "温度"
                    valueText: root.tempText
                    ratio: root.tempValue
                    accent: "#fcad70"
                }
            }

            Text {
                text: "后续可以把这些资源卡扩展成曲线视图和更长时间尺度的趋势图。"
                font.pixelSize: 11
                color: theme.subtext
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            DetailChip {
                icon: "timer"
                label: "运行时间"
                valueText: root.uptimeText
                accent: "#fcad70"
            }

            DetailChip {
                icon: "cake"
                label: "安装时长"
                valueText: root.osAgeText
                accent: "#81c995"
            }

            DetailChip {
                icon: "devices"
                label: "设备类型"
                valueText: root.chassisText
                accent: "#cba6f7"
            }
        }
    }
}
