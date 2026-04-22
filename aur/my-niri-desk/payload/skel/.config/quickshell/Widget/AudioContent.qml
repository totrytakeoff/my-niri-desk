import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Widget.common
import qs.config
import qs.Widget.audio
import QtQuick.Controls

WidgetPanel {
    id: root
    title: "混音器"
    icon: "\uf1de"
    closeAction: () => WidgetState.qsOpen = false
    Theme { id: theme }
    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "audio"
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    onIsActiveChanged: {
        if (isActive) {
            deviceScan.running = true;
        }
    }

    headerTools: Text {
        text: "\uf013"
        font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 20
        color: theme.subtext
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["pavucontrol"]) }
    }

    PwObjectTracker { objects: [ root.defaultSink, root.defaultSource ] }
    PwNodeLinkTracker { id: appTracker; node: root.defaultSink }

    Connections {
        target: root.defaultSink
        ignoreUnknownSignals: true
        function onDescriptionChanged() { if (root.isActive) deviceScan.running = true }
    }

    Connections {
        target: root.defaultSource
        ignoreUnknownSignals: true
        function onDescriptionChanged() { if (root.isActive) deviceScan.running = true }
    }
    
    function isHeadphone(node) {
        if (!node) return false;
        const icon = node.properties["device.icon-name"] || ""; 
        const desc = node.description || "";
        return icon.includes("headphone") || desc.toLowerCase().includes("headphone") || desc.toLowerCase().includes("耳机");
    }

    Rectangle {
        Layout.fillWidth: true
        height: 104 
        color: theme.surface; radius: theme.radius

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { 
                    text: isHeadphone(root.defaultSink) ? "\uf025" : "\uf028"
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 20; color: theme.primary 
                }
                Text { 
                    text: root.defaultSink ? (root.defaultSink.description || root.defaultSink.name) : "未找到设备"
                    font.bold: true; font.pixelSize: 15; color: theme.text; elide: Text.ElideRight; Layout.fillWidth: true 
                }
                Text { 
                    text: root.defaultSink ? Math.round(root.defaultSink.audio.volume * 100) + "%" : "0%"
                    font.bold: true; font.pixelSize: 15; color: theme.primary 
                }
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Qt.rgba(theme.surface_variant.r, theme.surface_variant.g, theme.surface_variant.b, 0.38)
                    visible: !!root.defaultSink

                    Text {
                        anchors.centerIn: parent
                        text: root.defaultSink && root.defaultSink.audio.muted ? "\uf6a9" : "\uf028"
                        font.family: "Font Awesome 7 Free Solid"
                        font.pixelSize: 13
                        color: theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.defaultSink) root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                    }
                }
            }

            VolumeSlider { node: root.defaultSink; isHeadphone: root.isHeadphone(root.defaultSink) }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 88
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        radius: theme.radius

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "\uf130"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 18
                    color: theme.primary
                }
                Text {
                    text: root.defaultSource ? (root.defaultSource.description || root.defaultSource.name) : "未找到输入设备"
                    font.bold: true
                    font.pixelSize: 14
                    color: theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.defaultSource ? Math.round(root.defaultSource.audio.volume * 100) + "%" : "0%"
                    font.bold: true
                    font.pixelSize: 14
                    color: theme.primary
                }
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: Qt.rgba(theme.surface_variant.r, theme.surface_variant.g, theme.surface_variant.b, 0.38)
                    visible: !!root.defaultSource

                    Text {
                        anchors.centerIn: parent
                        text: root.defaultSource && root.defaultSource.audio.muted ? "\uf131" : "\uf130"
                        font.family: "Font Awesome 7 Free Solid"
                        font.pixelSize: 12
                        color: theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.defaultSource) root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                    }
                }
            }

            VolumeSlider { node: root.defaultSource; isHeadphone: false }
        }
    }

    Text { text: "输出设备"; font.pixelSize: 13; color: theme.subtext; font.bold: true; Layout.topMargin: 8 }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: sinkModel.count > 0 ? 74 : 0
        clip: true
        orientation: ListView.Horizontal
        spacing: 10
        model: sinkModel
        visible: sinkModel.count > 0

        delegate: Rectangle {
            required property int nodeId
            required property string label
            required property bool active

            width: 164
            height: 64
            radius: 14
            color: active ? Colorscheme.primary_container : Colorscheme.surface_container_highest
            border.width: active ? 0 : 1
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: active ? "当前输出" : "可切换输出"
                    font.pixelSize: 10
                    color: active ? Colorscheme.on_primary_container : theme.subtext
                }
                Text {
                    text: label
                    font.bold: true
                    font.pixelSize: 12
                    color: active ? Colorscheme.on_primary_container : theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !active
                onClicked: {
                    setDefaultSinkProc.targetId = String(nodeId);
                    setDefaultSinkProc.running = true;
                }
            }
        }
    }

    Text { text: "输入设备"; font.pixelSize: 13; color: theme.subtext; font.bold: true; visible: sourceModel.count > 0 }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceModel.count > 0 ? 74 : 0
        clip: true
        orientation: ListView.Horizontal
        spacing: 10
        model: sourceModel
        visible: sourceModel.count > 0

        delegate: Rectangle {
            required property int nodeId
            required property string label
            required property bool active

            width: 164
            height: 64
            radius: 14
            color: active ? Colorscheme.secondary_container : Colorscheme.surface_container_highest
            border.width: active ? 0 : 1
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: active ? "当前输入" : "可切换输入"
                    font.pixelSize: 10
                    color: active ? Colorscheme.on_secondary_container : theme.subtext
                }
                Text {
                    text: label
                    font.bold: true
                    font.pixelSize: 12
                    color: active ? Colorscheme.on_secondary_container : theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !active
                onClicked: {
                    setDefaultSourceProc.targetId = String(nodeId);
                    setDefaultSourceProc.running = true;
                }
            }
        }
    }

    Text { text: "应用程序"; font.pixelSize: 14; color: theme.subtext; font.bold: true; Layout.topMargin: 12 }

    ListView {
        id: appList // 给 ListView 起个 id 方便滚轮调用
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: 12;
        model: appTracker.linkGroups

        // ============================================================
        // 【核心改造 1】：彻底禁用原生 ListView 的左键拖拽滑动功能
        // ============================================================
        interactive: false 

        // ============================================================
        // 【核心改造 2】：纯滚轮接管引擎
        // ============================================================
        MouseArea {
            anchors.fill: parent
            
            // 极其关键：告诉它“不要拦截任何鼠标按键”！
            // 这样所有的点击和拖拽操作都会完美穿透给底下的音量滑块！
            acceptedButtons: Qt.NoButton 
            
            // 手动接管滚轮事件，并限制上下边界防止滚出屏幕
            onWheel: (wheel) => {
                let newY = appList.contentY - wheel.angleDelta.y;
                let maxY = Math.max(0, appList.contentHeight - appList.height);
                
                if (newY < 0) newY = 0;
                if (newY > maxY) newY = maxY;
                
                appList.contentY = newY;
            }
        }

        delegate: Rectangle {
            Theme { id: itemTheme }
            required property PwLinkGroup modelData
            property var appNode: modelData.source

            width: ListView.view.width; height: 68
            radius: 12; color: "transparent"
            border.width: 1; border.color: "transparent" 
            PwObjectTracker { objects: [ appNode ] }

            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 14

                Image {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    visible: source != ""
                    source: {
                        const iconProperty = (appNode.properties["application.icon-name"] || "").toLowerCase();
                        const binaryName = (appNode.properties["application.process.binary"] || "").toLowerCase();

                        const iconMap = {
                            "zen": "zen-browser",
                            "zen-bin": "zen-browser",
                            "zen-alpha": "zen-browser",
                            "splayer": "file:///usr/share/icons/hicolor/512x512/apps/SPlayer.png"
                        };

                        let finalIcon = iconMap[binaryName] || iconMap[iconProperty] || iconProperty || binaryName || "audio-card";
                        
                        if (finalIcon.startsWith("file://") || finalIcon.startsWith("/")) {
                            return finalIcon.startsWith("/") ? "file://" + finalIcon : finalIcon;
                        }
                        
                        return `image://icon/${finalIcon}`;
                    }
                    onStatusChanged: { if (status === Image.Error) source = "image://icon/audio-card"; }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: appNode.properties["application.name"] || appNode.name; font.bold: true; font.pixelSize: 14; color: itemTheme.text; elide: Text.ElideRight; Layout.fillWidth: true }
                    }

                    Item {
                        Layout.fillWidth: true; height: 16
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6; radius: 3
                            color: Qt.rgba(itemTheme.text.r, itemTheme.text.g, itemTheme.text.b, 0.1)
                            Rectangle { height: parent.height; width: parent.width * appNode.audio.volume; radius: 3; color: itemTheme.primary }
                        }

                        Rectangle {
                            width: 6; height: 16; radius: 3; color: itemTheme.text 
                            x: Math.max(0, Math.min(parent.width * appNode.audio.volume - width / 2, parent.width - width))
                            anchors.verticalCenter: parent.verticalCenter

                            Item {
                                width: 32; height: 32
                                anchors.bottom: parent.top; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                                visible: sliderMouseArea.containsMouse || sliderMouseArea.pressed
                                
                                Rectangle {
                                    anchors.fill: parent; radius: 16; color: itemTheme.primary; rotation: 45 
                                    Rectangle { width: 16; height: 16; x: 16; y: 16; color: parent.color }
                                }
                                Text { anchors.centerIn: parent; text: Math.round(appNode.audio.volume * 100); color: itemTheme.surface; font.pixelSize: 11; font.bold: true }
                            }
                        }

                        MouseArea {
                            id: sliderMouseArea; anchors.fill: parent;
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            
                            // 【代码精简】：这里不再需要 preventStealing: true 了，因为外层的列表已经彻底失去了抢夺焦点的能力！
                            
                            function updateVolume(mouse) { 
                                let v = mouse.x / width;
                                if (v < 0) v = 0; if (v > 1) v = 1;
                                appNode.audio.volume = v 
                            }
                            onPressed: (mouse) => updateVolume(mouse)
                            onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse) }
                        }
                    }
                }
            }
        }
    }

    ListModel { id: sinkModel }
    ListModel { id: sourceModel }

    Process {
        id: deviceScan
        command: ["bash", "-lc", "wpctl status"]
        property string section: ""
        onStarted: {
            sinkModel.clear();
            sourceModel.clear();
            section = "";
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const text = line.trim();
                if (text === "") return;
                if (text.startsWith("├─ Sinks:") || text.startsWith("└─ Sinks:")) { deviceScan.section = "sinks"; return; }
                if (text.startsWith("├─ Sources:") || text.startsWith("└─ Sources:")) { deviceScan.section = "sources"; return; }
                if (text.startsWith("├─ Filters:") || text.startsWith("└─ Filters:") || text.startsWith("└─ Streams:") || text.startsWith("├─ Streams:") || text.startsWith("Video") || text.startsWith("Settings")) {
                    deviceScan.section = "";
                    return;
                }
                if (deviceScan.section !== "sinks" && deviceScan.section !== "sources") return;

                const match = text.match(/^(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:/);
                if (!match) return;

                const active = !!match[1];
                const nodeId = parseInt(match[2]);
                const label = match[3].trim();
                const targetModel = deviceScan.section === "sinks" ? sinkModel : sourceModel;
                targetModel.append({ nodeId: nodeId, label: label, active: active });
            }
        }
    }

    Process {
        id: setDefaultSinkProc
        property string targetId: ""
        command: ["wpctl", "set-default", targetId]
        onExited: deviceScan.running = true
    }

    Process {
        id: setDefaultSourceProc
        property string targetId: ""
        command: ["wpctl", "set-default", targetId]
        onExited: deviceScan.running = true
    }
}
