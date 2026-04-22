import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

WidgetPanel {
    id: root
    title: "网络配置"
    icon: "wifi" 
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "network"
    property bool wifiEnabled: true
    property string currentTab: "wifi"
    property string currentWifiSsid: ""
    property int currentWifiSignal: 0
    property string ethernetDevice: ""
    property string ethernetState: "unknown"
    property string ethernetConnection: ""
    property string statusText: ""
    property bool statusError: false
    
    property string mdFont: "Material Symbols Outlined"

    onIsActiveChanged: {
        if (isActive) {
            checkWifiStatus.running = true;
            scanWifi.running = true;
            networkMonitor.running = true;
            ethernetStatus.running = true;
        }
        else { networkMonitor.running = false }
    }

    function showStatus(message, isError) {
        root.statusText = message;
        root.statusError = !!isError;
        statusTimer.restart();
    }

    headerTools: RowLayout {
        Theme { id: headerTheme }
        spacing: 12
        
        Text {
            text: "sync"
            font.family: root.mdFont; font.pixelSize: 20
            color: headerTheme.subtext; opacity: scanWifi.running ? 0.5 : 1
            MouseArea { 
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                onClicked: { wifiModel.clear(); scanWifi.running = true } 
            }
            RotationAnimation on rotation { 
                running: scanWifi.running; from: 0; to: 360; loops: Animation.Infinite; duration: 1000 
            }
        }
        
        // 【优化】：缩小后的头部 Switch
        Rectangle {
            id: mainSwitch
            width: 44; height: 24; radius: 12 
            color: root.wifiEnabled ? headerTheme.primary : "transparent"
            border.width: root.wifiEnabled ? 0 : 2
            border.color: headerTheme.outline
            Behavior on color { ColorAnimation { duration: 250 } }
            
            Rectangle { 
                // 开启时16px，关闭时12px
                width: root.wifiEnabled ? 16 : 12
                height: root.wifiEnabled ? 16 : 12
                radius: width / 2
                x: root.wifiEnabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: root.wifiEnabled ? Colorscheme.on_primary : headerTheme.outline
                
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } 
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    font.family: root.mdFont
                    font.pixelSize: 12 // 图标等比例缩小
                    font.bold: true
                    color: headerTheme.primary
                    opacity: root.wifiEnabled ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
            
            MouseArea { 
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.wifiEnabled = !root.wifiEnabled
                    if (!root.wifiEnabled) { wifiModel.clear(); scanWifi.running = false } 
                    else { scanWifi.running = true }
                    toggleWifiProc.running = true 
                }
            }
        }
    }

    Rectangle {
        Theme { id: summaryTheme }
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: 16
        color: Qt.rgba(summaryTheme.surface.r, summaryTheme.surface.g, summaryTheme.surface.b, 0.42)
        border.width: 1
        border.color: Qt.rgba(summaryTheme.outline.r, summaryTheme.outline.g, summaryTheme.outline.b, 0.4)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: root.wifiEnabled && root.currentWifiSsid !== "" ? summaryTheme.primary_container : Colorscheme.surface_container_highest

                Text {
                    anchors.centerIn: parent
                    text: "wifi"
                    font.family: root.mdFont
                    font.pixelSize: 21
                    color: root.wifiEnabled && root.currentWifiSsid !== "" ? Colorscheme.on_primary_container : summaryTheme.text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.wifiEnabled
                        ? (root.currentWifiSsid !== "" ? root.currentWifiSsid : "Wi-Fi 已开启")
                        : "Wi-Fi 已关闭"
                    font.bold: true
                    font.pixelSize: 14
                    color: summaryTheme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.wifiEnabled
                        ? (root.currentWifiSsid !== "" ? ("已连接 · 信号 " + root.currentWifiSignal + "%") : "正在等待可用网络")
                        : "打开后可扫描并连接附近网络"
                    font.pixelSize: 12
                    color: root.currentWifiSsid !== "" ? summaryTheme.primary : summaryTheme.subtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.ethernetState === "connected"
                        ? ("有线网络在线" + (root.ethernetConnection !== "" ? " · " + root.ethernetConnection : ""))
                        : (root.ethernetDevice !== "" ? "有线网卡已检测" : "未检测到有线网络")
                    font.pixelSize: 11
                    color: summaryTheme.subtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    Rectangle {
        Theme { id: tabTheme }
        Layout.fillWidth: true; height: 42
        color: "transparent"
        
        RowLayout {
            anchors.fill: parent; spacing: 0
            
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { 
                    anchors.centerIn: parent
                    text: "Wi-Fi"; font.bold: true; font.pixelSize: 14; 
                    color: root.currentTab === "wifi" ? tabTheme.primary : tabTheme.text 
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Rectangle {
                    width: 48; height: 3; radius: 1.5
                    color: tabTheme.primary
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.currentTab === "wifi" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; onClicked: root.currentTab = "wifi" }
            }
            
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { 
                    anchors.centerIn: parent
                    text: "以太网"; font.bold: true; font.pixelSize: 14; 
                    color: root.currentTab === "ethernet" ? tabTheme.primary : tabTheme.text 
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Rectangle {
                    width: 48; height: 3; radius: 1.5
                    color: tabTheme.primary
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.currentTab === "ethernet" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; onClicked: root.currentTab = "ethernet" }
            }
        }
        
        Rectangle {
            width: parent.width; height: 1; color: tabTheme.outline
            anchors.bottom: parent.bottom; opacity: 0.3
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.statusText !== "" ? 34 : 0
        visible: root.statusText !== ""
        radius: 17
        color: root.statusError
            ? Qt.rgba(tabTheme.error.r, tabTheme.error.g, tabTheme.error.b, 0.16)
            : Qt.rgba(tabTheme.primary.r, tabTheme.primary.g, tabTheme.primary.b, 0.14)
        border.width: 1
        border.color: root.statusError
            ? Qt.rgba(tabTheme.error.r, tabTheme.error.g, tabTheme.error.b, 0.24)
            : Qt.rgba(tabTheme.primary.r, tabTheme.primary.g, tabTheme.primary.b, 0.22)

        Text {
            anchors.centerIn: parent
            text: root.statusText
            font.pixelSize: 12
            font.bold: true
            color: root.statusError ? tabTheme.error : tabTheme.text
        }
    }

    StackLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        currentIndex: root.currentTab === "wifi" ? 0 : 1
        
        ColumnLayout {
            spacing: 8
            Theme { id: contentTheme }
            Text { text: "网络列表"; color: contentTheme.subtext; font.pixelSize: 14; font.bold: true; Layout.topMargin: 12 }

            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 10; model: wifiModel 
                
                delegate: Rectangle {
                    Theme { id: itemTheme }
                    height: 68; width: ListView.view.width; radius: 12; color: "transparent" 
                    border.width: 1; border.color: ma.containsMouse ? itemTheme.primary : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 14
                        
                        Text {
                            text: "wifi"
                            font.family: root.mdFont; font.pixelSize: 24 
                            color: model.connected ? itemTheme.primary : itemTheme.subtext
                            opacity: model.connected ? 1 : (model.signal / 100)
                        }
                        
                        ColumnLayout {
                            spacing: 2; Layout.alignment: Qt.AlignVCenter
                            Text { text: model.ssid; font.bold: true; font.pixelSize: 14; color: model.connected ? itemTheme.primary : itemTheme.text }
                            RowLayout {
                                spacing: 4
                                Text { 
                                    text: model.connected ? "check" : "lock"
                                    font.family: root.mdFont; font.pixelSize: 14;
                                    color: model.connected ? itemTheme.primary : itemTheme.subtext 
                                }
                                Text { 
                                    text: model.connected ? "已连接" : (model.security === "" ? "Open" : model.security); 
                                    font.pixelSize: 12; color: model.connected ? itemTheme.primary : itemTheme.subtext 
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // 【优化】：缩小后的列表项 Switch
                        Rectangle {
                            visible: ma.containsMouse || model.connected
                            width: 44; height: 24; radius: 12 
                            color: model.connected ? itemTheme.primary : "transparent"
                            border.width: model.connected ? 0 : 2
                            border.color: itemTheme.outline
                            Behavior on color { ColorAnimation { duration: 250 } }
                            
                            Rectangle { 
                                width: model.connected ? 16 : 12
                                height: model.connected ? 16 : 12
                                radius: width / 2
                                x: model.connected ? parent.width - width - 4 : 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: model.connected ? Colorscheme.on_primary : itemTheme.outline
                                
                                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } 
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "check"
                                    font.family: root.mdFont
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: itemTheme.primary
                                    opacity: model.connected ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.connected) {
                                        // 1. 断开：先立刻更新UI状态
                                        wifiModel.setProperty(index, "connected", false)
                                        // 2. 执行命令
                                        root.currentWifiSsid = "";
                                        root.currentWifiSignal = 0;
                                        disconnectProc.targetSsid = model.ssid;
                                        disconnectProc.running = true
                                    } else {
                                        // 【核心修复】：乐观更新！立刻清除其他所有网络的连接状态，点亮当前网络
                                        for(let i = 0; i < wifiModel.count; i++) {
                                            if (wifiModel.get(i).connected) {
                                                wifiModel.setProperty(i, "connected", false)
                                            }
                                        }
                                        wifiModel.setProperty(index, "connected", true)
                                        
                                        // 执行连接命令
                                        root.currentWifiSsid = model.ssid;
                                        root.currentWifiSignal = model.signal;
                                        connectProc.targetSsid = model.ssid;
                                        connectProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Theme { id: ethTheme }
            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: 16
                    color: Qt.rgba(ethTheme.surface.r, ethTheme.surface.g, ethTheme.surface.b, 0.38)
                    border.width: 1
                    border.color: Qt.rgba(ethTheme.outline.r, ethTheme.outline.g, ethTheme.outline.b, 0.45)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 22
                            color: root.ethernetState === "connected"
                                ? ethTheme.primary
                                : Colorscheme.surface_container_highest

                            Text {
                                anchors.centerIn: parent
                                text: "settings_ethernet"
                                font.family: root.mdFont
                                font.pixelSize: 22
                                color: root.ethernetState === "connected"
                                    ? Colorscheme.on_primary
                                    : ethTheme.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root.ethernetDevice !== "" ? root.ethernetDevice : "未检测到有线网卡"
                                font.bold: true
                                font.pixelSize: 14
                                color: ethTheme.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.ethernetState === "connected"
                                    ? "已连接" + (root.ethernetConnection !== "" ? " · " + root.ethernetConnection : "")
                                    : (root.ethernetState === "unavailable" ? "网线未接入" : "当前未连接")
                                font.pixelSize: 12
                                color: root.ethernetState === "connected" ? ethTheme.primary : ethTheme.subtext
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "有线网络更适合稳定下载、远程桌面和大型文件传输。"
                                font.pixelSize: 11
                                color: ethTheme.subtext
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Colorscheme.surface_container_highest

                    Text {
                        anchors.centerIn: parent
                        text: "打开网络设置"
                        font.bold: true
                        font.pixelSize: 12
                        color: ethTheme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["gnome-control-center", "network"])
                    }
                }
            }
        }
    }

    ListModel { id: wifiModel }

    Process { id: networkMonitor; command: ["nmcli", "monitor"]; running: root.isActive
        stdout: SplitParser { onRead: (data) => {
            const str = data.toLowerCase();
            if (str.includes("connected") || str.includes("disconnected") || str.includes("unavailable") || str.includes("using connection")) {
                if (root.wifiEnabled) scanWifi.running = true;
                ethernetStatus.running = true;
            }
        } }
    }
    Timer {
        id: statusTimer
        interval: 2400
        repeat: false
        onTriggered: root.statusText = ""
    }
    Process { id: checkWifiStatus; command: ["nmcli", "radio", "wifi"]; running: root.isActive
        stdout: SplitParser { onRead: (data) => { let status = (data.trim() === "enabled"); root.wifiEnabled = status; if (status && wifiModel.count === 0) scanWifi.running = true } }
    }
    Process { id: scanWifi; command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list"]
        onStarted: {
            wifiModel.clear();
            root.currentWifiSsid = "";
            root.currentWifiSignal = 0;
        }
        stdout: SplitParser { splitMarker: "\n"; onRead: (data) => parseWifiData(data) }
    }
    Process {
        id: ethernetStatus
        command: ["bash", "-lc", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | awk -F: '$2==\"ethernet\" && $1 !~ /^veth/ {print; exit}'"]
        stdout: SplitParser {
            onRead: (data) => {
                const line = data.trim();
                if (line === "") {
                    root.ethernetDevice = "";
                    root.ethernetState = "unknown";
                    root.ethernetConnection = "";
                    return;
                }
                const parts = line.split(":");
                root.ethernetDevice = parts[0] || "";
                root.ethernetState = parts[2] || "unknown";
                root.ethernetConnection = parts.slice(3).join(":") || "";
            }
        }
    }
    Process { id: toggleWifiProc; command: ["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"]; onExited: (code) => { if (root.wifiEnabled) scanWifi.running = true } }
    
    // 【核心修复】：添加 onExited 回调，无论 nmcli 执行成功还是失败，完成后都重新扫描一遍确保状态准确
    Process { 
        id: connectProc; property string targetSsid: ""; command: ["nmcli", "device", "wifi", "connect", targetSsid]; 
        onExited: {
            root.showStatus(code === 0 ? ("已连接到 " + targetSsid) : ("连接失败: " + targetSsid), code !== 0);
            scanWifi.running = true;
        } 
    }
    Process { 
        id: disconnectProc; property string targetSsid: ""; command: ["nmcli", "connection", "down", targetSsid]; 
        onExited: {
            root.showStatus(code === 0 ? ("已断开 " + targetSsid) : ("断开失败: " + targetSsid), code !== 0);
            scanWifi.running = true;
        } 
    }

    function parseWifiData(line) {
        if (!root.wifiEnabled || line.trim() === "") return;
        let lastColon = line.lastIndexOf(":")
        let inUse = line.substring(lastColon + 1)
        let temp1 = line.substring(0, lastColon)
        let secondLastColon = temp1.lastIndexOf(":")
        let security = temp1.substring(secondLastColon + 1)
        let temp2 = temp1.substring(0, secondLastColon)
        let thirdLastColon = temp2.lastIndexOf(":")
        let signal = parseInt(temp2.substring(thirdLastColon + 1))
        let ssid = temp2.substring(0, thirdLastColon).replace(/\\:/g, ":")

        if (ssid === "") return;
        let isConnected = (inUse === "*");
        if (isConnected) {
            root.currentWifiSsid = ssid;
            root.currentWifiSignal = signal;
            for(let i = 0; i < wifiModel.count; i++) { if (wifiModel.get(i).connected) wifiModel.setProperty(i, "connected", false); }
        }
        let existingIndex = -1;
        for(let i = 0; i < wifiModel.count; i++) { if (wifiModel.get(i).ssid === ssid) { existingIndex = i; break; } }
        if (existingIndex !== -1) {
            wifiModel.setProperty(existingIndex, "signal", signal);
            wifiModel.setProperty(existingIndex, "connected", isConnected);
            if (isConnected) wifiModel.move(existingIndex, 0, 1);
        } else {
            let item = { ssid: ssid, signal: signal, security: security === "" ? "Open" : security, connected: isConnected };
            if (isConnected) wifiModel.insert(0, item); else wifiModel.append(item);
        }
    }
}
