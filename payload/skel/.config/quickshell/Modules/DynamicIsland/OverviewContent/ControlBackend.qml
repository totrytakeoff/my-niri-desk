import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services as Services
pragma Singleton

Singleton {
    id: root

    property bool wifiEnabled: false
    property bool bluetoothEnabled: Services.Bluetooth.powered
    property bool bluetoothConnected: Services.Bluetooth.connectedCount > 0
    property bool dndEnabled: false
    property real brightnessValue: 0.5

    function toggleWifi() {
        Quickshell.execDetached(["bash", "-c", root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]);
        root.wifiEnabled = !root.wifiEnabled;
        debounceTimer.start();
    }

    function toggleBluetooth() {
        Services.Bluetooth.togglePower();
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

    function setBrightness(val) {
        let pct = Math.round(Math.max(0.01, Math.min(1, val)) * 100);
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
        root.brightnessValue = val;
    }

    Process {
        id: statusPoller

        command: ["bash", "-c", `
                        WIFI=$(nmcli -t -f WIFI g 2>/dev/null)
                        echo "WIFI:$WIFI"

                        BRI=$(brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}')
                        echo "BRI:$BRI"
                `]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let data = line.trim();
                if (data === "")
                    return ;

                if (data.startsWith("WIFI:")) {
                    root.wifiEnabled = (data.substring(5) === "enabled");
                } else if (data.startsWith("BRI:")) {
                    let b = parseInt(data.substring(4));
                    if (!isNaN(b))
                        root.brightnessValue = b / 100;

                }
            }
        }

    }

    Timer {
        id: pollTimer

        interval: 5000
        running: true
        repeat: true
        onTriggered: statusPoller.running = true
    }

    Timer {
        id: debounceTimer

        interval: 200
        running: false
        repeat: false
        onTriggered: statusPoller.running = true
    }

}
