import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

Item {
    id: root
    Theme { id: theme }

    property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "processes"
    property int processCount: 0
    property string sortMode: "cpu"
    property string filterText: ""
    property real totalCpuPercent: 0
    property real totalMemPercent: 0
    property real sampleCpuTotal: 0
    property real sampleMemMb: 0
    property real sampleMemPercent: 0
    property int selectedPid: -1
    property string selectedName: ""
    property string selectedCmdline: ""
    property string selectedStatus: ""
    property real selectedCpu: 0
    property real selectedMemMb: 0
    property real selectedMemPercent: 0
    property int selectedAgeSec: 0

    function refresh() {
        if (!procList.running) {
            procList.running = true;
        }
    }

    onIsForegroundChanged: {
        if (isForeground) refresh();
    }

    Timer {
        interval: 4000
        running: root.isForeground
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: procList
        command: [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/process_overview.py",
            "--limit", "28",
            "--sort", root.sortMode
        ]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const payload = JSON.parse(data.trim());
                    const rows = payload.rows || [];
                    processModel.clear();
                    for (let i = 0; i < rows.length; ++i) {
                        processModel.append(rows[i]);
                    }
                    root.processCount = rows.length;
                    root.totalCpuPercent = payload.summary ? payload.summary.cpu_percent : 0;
                    root.totalMemPercent = payload.summary ? payload.summary.mem_percent : 0;
                    root.sampleCpuTotal = payload.summary ? payload.summary.sample_cpu_total : 0;
                    root.sampleMemMb = payload.summary ? payload.summary.sample_mem_mb : 0;
                    root.sampleMemPercent = payload.summary ? payload.summary.sample_mem_percent : 0;

                    if (root.selectedPid !== -1) {
                        let found = false;
                        for (let i = 0; i < rows.length; ++i) {
                            if (rows[i].pid === root.selectedPid) {
                                root.selectProcess(rows[i]);
                                found = true;
                                break;
                            }
                        }
                        if (!found && rows.length > 0)
                            root.selectProcess(rows[0]);
                    } else if (rows.length > 0) {
                        root.selectProcess(rows[0]);
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: terminateProc
        property string targetPid: ""
        command: ["kill", "-TERM", targetPid]
        onExited: root.refresh()
    }

    Process {
        id: forceTerminateProc
        property string targetPid: ""
        command: ["kill", "-KILL", targetPid]
        onExited: root.refresh()
    }

    ListModel { id: processModel }

    component SortChip : Rectangle {
        property string value: ""
        property string label: ""
        property bool active: root.sortMode === value

        radius: 16
        implicitWidth: chipLabel.implicitWidth + 20
        implicitHeight: 30
        color: active ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.18)
                      : Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.22)
        border.width: 1
        border.color: active ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.28)
                             : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.24)

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: label
            font.pixelSize: 11
            font.bold: true
            color: active ? Colorscheme.primary : theme.subtext
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.sortMode = value;
                root.refresh();
            }
        }
    }

    function statusLabel(status) {
        if (status === "running") return "RUN";
        if (status === "sleeping") return "SLEEP";
        if (status === "disk-sleep") return "IO";
        if (status === "stopped") return "STOP";
        if (status === "zombie") return "ZOMB";
        return status.toUpperCase();
    }

    function statusColor(status) {
        if (status === "running") return Colorscheme.primary;
        if (status === "sleeping") return Colorscheme.secondary;
        if (status === "disk-sleep") return Colorscheme.tertiary;
        if (status === "stopped" || status === "zombie") return Colorscheme.error;
        return theme.subtext;
    }

    function ageLabel(seconds) {
        if (seconds < 60) return seconds + "s";
        if (seconds < 3600) return Math.floor(seconds / 60) + "m";
        if (seconds < 86400) return Math.floor(seconds / 3600) + "h";
        return Math.floor(seconds / 86400) + "d";
    }

    function selectProcess(row) {
        if (!row)
            return;
        root.selectedPid = row.pid;
        root.selectedName = row.name;
        root.selectedCmdline = row.cmdline;
        root.selectedStatus = row.status;
        root.selectedCpu = row.cpu;
        root.selectedMemMb = row.mem_mb;
        root.selectedMemPercent = row.mem_percent;
        root.selectedAgeSec = row.age_sec;
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
                Layout.preferredHeight: headerCol.implicitHeight + 32
                implicitHeight: headerCol.implicitHeight + 32
                radius: 18
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

                ColumnLayout {
                    id: headerCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "进程"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 24
                                font.bold: true
                                color: theme.text
                            }

                            Text {
                                text: "轻量进程视图，支持排序、筛选与快速结束。"
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

                    Text {
                        text: "当前采样 " + root.processCount + " 个用户进程 · 排序: " + (root.sortMode === "cpu" ? "CPU" : (root.sortMode === "mem" ? "内存" : "名称"))
                        font.pixelSize: 11
                        color: theme.subtext
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SortChip { value: "cpu"; label: "CPU" }
                        SortChip { value: "mem"; label: "内存" }
                        SortChip { value: "name"; label: "名称" }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 32
                            radius: 16
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.22)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: "search"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: theme.subtext
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    color: theme.text
                                    font.pixelSize: 12
                                    clip: true
                                    selectedTextColor: Colorscheme.on_primary
                                    selectionColor: Colorscheme.primary
                                    text: root.filterText
                                    onTextChanged: root.filterText = text

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "筛选进程名 / 命令"
                                        color: theme.subtext
                                        font.pixelSize: 12
                                        visible: !searchInput.text && !searchInput.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 16
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text { text: "系统 CPU"; font.pixelSize: 10; color: theme.subtext }
                                Text { text: root.totalCpuPercent.toFixed(1) + "%"; font.pixelSize: 18; font.bold: true; color: Colorscheme.primary }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 16
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text { text: "系统内存"; font.pixelSize: 10; color: theme.subtext }
                                Text { text: root.totalMemPercent.toFixed(1) + "%"; font.pixelSize: 18; font.bold: true; color: Colorscheme.secondary }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 16
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text { text: "当前列表"; font.pixelSize: 10; color: theme.subtext }
                                Text { text: root.sampleMemMb.toFixed(0) + "M"; font.pixelSize: 18; font.bold: true; color: theme.text }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.88)
                border.width: 1
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: root.selectedName !== "" ? (root.selectedName + " · " + root.selectedPid) : "选择一个进程"
                            font.bold: true
                            font.pixelSize: 13
                            color: theme.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            radius: 9
                            implicitWidth: root.statusLabel(root.selectedStatus).length * 8 + 16
                            implicitHeight: 18
                            color: Qt.rgba(root.statusColor(root.selectedStatus).r, root.statusColor(root.selectedStatus).g, root.statusColor(root.selectedStatus).b, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: root.statusLabel(root.selectedStatus)
                                font.pixelSize: 10
                                font.bold: true
                                color: root.statusColor(root.selectedStatus)
                            }
                        }
                    }

                    Text {
                        text: root.selectedCmdline !== "" ? root.selectedCmdline : "No command line available"
                        font.pixelSize: 11
                        color: theme.subtext
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text { text: "CPU " + root.selectedCpu.toFixed(1) + "%"; font.pixelSize: 11; color: Colorscheme.primary }
                        Text { text: "内存 " + root.selectedMemMb.toFixed(0) + "M"; font.pixelSize: 11; color: Colorscheme.secondary }
                        Text { text: "占比 " + root.selectedMemPercent.toFixed(1) + "%"; font.pixelSize: 11; color: theme.text }
                        Text { text: "运行 " + root.ageLabel(root.selectedAgeSec); font.pixelSize: 11; color: theme.subtext }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: processCol.implicitHeight + 24
                implicitHeight: processCol.implicitHeight + 24
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.88)
                border.width: 1
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.42)

                ColumnLayout {
                    id: processCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text { text: "进程"; font.bold: true; font.pixelSize: 11; color: theme.subtext; Layout.fillWidth: true }
                        Text { text: "CPU"; font.bold: true; font.pixelSize: 11; color: theme.subtext; Layout.preferredWidth: 46 }
                        Text { text: "MEM"; font.bold: true; font.pixelSize: 11; color: theme.subtext; Layout.preferredWidth: 58 }
                        Text { text: "操作"; font.bold: true; font.pixelSize: 11; color: theme.subtext; Layout.preferredWidth: 56 }
                    }

                    Repeater {
                        model: processModel

                        delegate: Rectangle {
                            required property int pid
                            required property string name
                            required property real cpu
                            required property real mem_mb
                            required property real mem_percent
                            required property string status
                            required property string cmdline
                            required property int age_sec

                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 84 : 0
                            visible: root.filterText === ""
                                || name.toLowerCase().includes(root.filterText.toLowerCase())
                                || cmdline.toLowerCase().includes(root.filterText.toLowerCase())
                            radius: 14
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.22)
                            border.width: 1
                            border.color: root.selectedPid === pid
                                ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.42)
                                : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.24)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: name + " · " + pid
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: theme.text
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            radius: 9
                                            implicitWidth: statusLabel(status).length * 8 + 16
                                            implicitHeight: 18
                                            color: Qt.rgba(root.statusColor(status).r, root.statusColor(status).g, root.statusColor(status).b, 0.14)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.statusLabel(status)
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: root.statusColor(status)
                                            }
                                        }

                                        Text {
                                            text: "运行 " + root.ageLabel(age_sec)
                                            font.pixelSize: 10
                                            color: theme.subtext
                                        }

                                        Text {
                                            text: cmdline !== "" ? cmdline : status
                                            font.pixelSize: 10
                                            color: theme.subtext
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)

                                            Rectangle {
                                                width: Math.min(parent.width, parent.width * Math.min(cpu, 100) / 100)
                                                height: parent.height
                                                radius: 3
                                                color: cpu >= 30 ? Colorscheme.error : Colorscheme.primary
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)

                                            Rectangle {
                                                width: Math.min(parent.width, parent.width * Math.min(mem_percent, 100) / 100)
                                                height: parent.height
                                                radius: 3
                                                color: Colorscheme.secondary
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectProcess({ pid, name, cpu, mem_mb, mem_percent, status, cmdline, age_sec })
                                }

                                Text {
                                    text: cpu.toFixed(1) + "%"
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: cpu >= 30 ? Colorscheme.error : Colorscheme.primary
                                    Layout.preferredWidth: 46
                                }

                                Text {
                                    text: mem_mb.toFixed(0) + "M"
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 11
                                    color: theme.text
                                    Layout.preferredWidth: 58
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 54
                                    spacing: 6

                                    Rectangle {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.12)
                                        border.width: 1
                                        border.color: Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.28)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "结束"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Colorscheme.error
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                terminateProc.targetPid = String(pid);
                                                terminateProc.running = true;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.20)
                                        border.width: 1
                                        border.color: Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.40)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "强退"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Colorscheme.error
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                forceTerminateProc.targetPid = String(pid);
                                                forceTerminateProc.running = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
