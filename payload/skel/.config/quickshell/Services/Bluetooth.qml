import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property alias devices: deviceModel
    property bool powered: false
    property bool powerBusy: false
    property bool scanning: false
    property bool refreshing: false
    property string busyMac: ""
    property string busyAction: ""
    property int connectedCount: 0
    property int pairedCount: 0
    property int availableCount: 0
    property string statusText: ""
    property bool statusError: false
    property var pendingDevices: []
    property bool pendingPowered: false
    property bool refreshQueued: false

    function validMac(mac) {
        return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac || "");
    }

    function deviceIndex(mac) {
        for (let i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).mac === mac)
                return i;

        }
        return -1;
    }

    function stateRank(device) {
        if (device.connected)
            return 0;

        if (device.paired)
            return 1;

        return 2;
    }

    function stateGroup(device) {
        if (device.connected)
            return "已连接";

        if (device.paired)
            return "已配对";

        return "附近设备";
    }

    function updateCounts() {
        let connected = 0;
        let paired = 0;
        let available = 0;
        for (let i = 0; i < deviceModel.count; i++) {
            const device = deviceModel.get(i);
            if (device.connected)
                connected++;

            if (device.paired)
                paired++;

            if (!device.paired)
                available++;

        }
        root.connectedCount = connected;
        root.pairedCount = paired;
        root.availableCount = available;
    }

    function reconcileDevices(snapshot) {
        const sorted = snapshot.slice().sort((left, right) => {
            const rankDifference = root.stateRank(left) - root.stateRank(right);
            if (rankDifference !== 0)
                return rankDifference;

            return left.name.localeCompare(right.name);
        });
        for (let i = deviceModel.count - 1; i >= 0; i--) {
            const mac = deviceModel.get(i).mac;
            if (!sorted.some((device) => {
                return device.mac === mac;
            }))
                deviceModel.remove(i);

        }
        for (let wantedIndex = 0; wantedIndex < sorted.length; wantedIndex++) {
            const incoming = sorted[wantedIndex];
            incoming.group = root.stateGroup(incoming);
            let currentIndex = root.deviceIndex(incoming.mac);
            if (currentIndex < 0) {
                deviceModel.insert(wantedIndex, incoming);
                continue;
            }
            for (const key of ["name", "connected", "paired", "trusted", "iconName", "group"]) deviceModel.setProperty(currentIndex, key, incoming[key])
            currentIndex = root.deviceIndex(incoming.mac);
            if (currentIndex !== wantedIndex)
                deviceModel.move(currentIndex, wantedIndex, 1);

        }
        root.updateCounts();
    }

    function parseSnapshotLine(line) {
        const trimmed = line.trim();
        if (trimmed === "")
            return ;

        if (trimmed.startsWith("__POWER__|")) {
            root.pendingPowered = trimmed.substring(10) === "yes";
            return ;
        }
        const parts = trimmed.split("|");
        if (parts.length < 6)
            return ;

        const mac = parts[0];
        if (!root.validMac(mac))
            return ;

        root.pendingDevices.push({
            "mac": mac,
            "connected": parts[1] === "yes",
            "paired": parts[2] === "yes",
            "trusted": parts[3] === "yes",
            "iconName": parts[4],
            "name": parts.slice(5).join("|")
        });
    }

    function refresh() {
        if (refreshProcess.running) {
            root.refreshQueued = true;
            return ;
        }
        refreshProcess.running = true;
    }

    function showStatus(message, isError) {
        root.statusText = message;
        root.statusError = !!isError;
        statusTimer.restart();
    }

    function setPowered(enable) {
        if (root.powerBusy || root.scanning || root.busyMac !== "")
            return ;

        powerProcess.targetPower = enable;
        powerProcess.running = true;
    }

    function togglePower() {
        root.setPowered(!root.powered);
    }

    function scan() {
        if (!root.powered || root.powerBusy || root.scanning || root.busyMac !== "")
            return ;

        discoveryProcess.running = true;
    }

    function connectDevice(mac) {
        if (!root.powered || root.scanning || root.busyMac !== "" || !root.validMac(mac))
            return ;

        root.busyMac = mac;
        root.busyAction = "连接中";
        connectProcess.targetMac = mac;
        connectProcess.running = true;
    }

    function disconnectDevice(mac) {
        if (!root.powered || root.scanning || root.busyMac !== "" || !root.validMac(mac))
            return ;

        root.busyMac = mac;
        root.busyAction = "断开中";
        disconnectProcess.targetMac = mac;
        disconnectProcess.running = true;
    }

    function pairDevice(mac) {
        if (!root.powered || root.scanning || root.busyMac !== "" || !root.validMac(mac))
            return ;

        root.busyMac = mac;
        root.busyAction = "配对中";
        pairProcess.targetMac = mac;
        pairProcess.running = true;
    }

    function unpairDevice(mac) {
        if (!root.powered || root.scanning || root.busyMac !== "" || !root.validMac(mac))
            return ;

        root.busyMac = mac;
        root.busyAction = "移除中";
        removeProcess.targetMac = mac;
        removeProcess.running = true;
    }

    Component.onCompleted: root.refresh()

    ListModel {
        id: deviceModel

        dynamicRoles: true
    }

    Timer {
        interval: 6000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1400
        repeat: true
        running: root.scanning
        onTriggered: root.refresh()
    }

    Timer {
        id: statusTimer

        interval: 2800
        repeat: false
        onTriggered: root.statusText = ""
    }

    Process {
        id: refreshProcess

        command: ["bash", "-lc", `
            controller=$(bluetoothctl show 2>/dev/null) || exit 1
            power=no
            printf '%s\n' "$controller" | grep -q 'Powered: yes' && power=yes
            printf '__POWER__|%s\n' "$power"

            devices=$(bluetoothctl devices 2>/dev/null)
            paired_devices=$(bluetoothctl devices Paired 2>/dev/null)
            connected_devices=$(bluetoothctl devices Connected 2>/dev/null)

            printf '%s\n' "$devices" | while read -r _ mac name; do
                [ -z "$mac" ] && continue
                connected=no
                paired=no
                trusted=no
                icon=""

                printf '%s\n' "$connected_devices" | grep -Fq "Device $mac " && connected=yes
                printf '%s\n' "$paired_devices" | grep -Fq "Device $mac " && paired=yes

                if [ "$paired" = yes ] || [ "$connected" = yes ]; then
                    info=$(bluetoothctl info "$mac" 2>/dev/null)
                    printf '%s\n' "$info" | grep -q 'Trusted: yes' && trusted=yes
                    icon=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*Icon: //p' | head -n 1)
                fi

                printf '%s|%s|%s|%s|%s|%s\n' "$mac" "$connected" "$paired" "$trusted" "$icon" "$name"
            done
        `]
        onStarted: {
            root.refreshing = true;
            root.pendingDevices = [];
            root.pendingPowered = root.powered;
        }
        onExited: (exitCode, exitStatus) => {
            root.refreshing = false;
            if (exitCode === 0) {
                root.powered = root.pendingPowered;
                root.reconcileDevices(root.pendingDevices);
            }
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                return root.parseSnapshotLine(data);
            }
        }

    }

    Process {
        id: discoveryProcess

        command: ["bash", "-lc", "bluetoothctl --timeout 8 scan on >/dev/null 2>&1; result=$?; bluetoothctl scan off >/dev/null 2>&1; exit $result"]
        onStarted: {
            root.scanning = true;
            root.showStatus("正在扫描附近设备", false);
        }
        onExited: (exitCode, exitStatus) => {
            root.scanning = false;
            root.showStatus(exitCode === 0 ? "扫描完成" : "扫描失败", exitCode !== 0);
            root.refresh();
        }
    }

    Process {
        id: powerProcess

        property bool targetPower: true

        command: ["bluetoothctl", "power", targetPower ? "on" : "off"]
        onStarted: root.powerBusy = true
        onExited: (exitCode, exitStatus) => {
            root.powerBusy = false;
            if (exitCode === 0)
                root.powered = targetPower;

            root.showStatus(exitCode === 0 ? (targetPower ? "蓝牙已开启" : "蓝牙已关闭") : "蓝牙电源切换失败", exitCode !== 0);
            root.refresh();
        }
    }

    Process {
        id: connectProcess

        property string targetMac: ""

        command: ["bluetoothctl", "connect", targetMac]
        onExited: (exitCode, exitStatus) => {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(exitCode === 0 ? "设备已连接" : "连接失败", exitCode !== 0);
            root.refresh();
        }
    }

    Process {
        id: disconnectProcess

        property string targetMac: ""

        command: ["bluetoothctl", "disconnect", targetMac]
        onExited: (exitCode, exitStatus) => {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(exitCode === 0 ? "设备已断开" : "断开失败", exitCode !== 0);
            root.refresh();
        }
    }

    Process {
        id: pairProcess

        property string targetMac: ""

        command: ["bash", "-lc", `
            mac="${targetMac}"
            bluetoothctl pair "$mac" >/dev/null 2>&1 || exit 10
            bluetoothctl trust "$mac" >/dev/null 2>&1 || exit 11
            bluetoothctl connect "$mac" >/dev/null 2>&1 || exit 12
        `]
        onExited: (exitCode, exitStatus) => {
            root.busyMac = "";
            root.busyAction = "";
            let message = "配对并连接成功";
            if (exitCode === 10)
                message = "设备配对失败";
            else if (exitCode === 11)
                message = "设备已配对，但信任失败";
            else if (exitCode === 12)
                message = "设备已配对，但连接失败";
            else if (exitCode !== 0)
                message = "配对或连接失败";
            root.showStatus(message, exitCode !== 0);
            root.refresh();
        }
    }

    Process {
        id: removeProcess

        property string targetMac: ""

        command: ["bluetoothctl", "remove", targetMac]
        onExited: (exitCode, exitStatus) => {
            root.busyMac = "";
            root.busyAction = "";
            root.showStatus(exitCode === 0 ? "已取消配对" : "取消配对失败", exitCode !== 0);
            root.refresh();
        }
    }

}
