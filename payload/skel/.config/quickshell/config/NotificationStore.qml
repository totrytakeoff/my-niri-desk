// config/NotificationStore.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property ListModel model: ListModel {}
    // 五个通知分组每组最多展示 50 条，Store 留出对应的全局容量。
    property int maxCount: 250
    property var privacyApps: ["qq", "wechat", "telegram", "discord"]
    readonly property string notifyCmd: "notify-db"

    Component.onCompleted: {
        loadProcess.running = true
    }

    property var loadProcess: Process {
        command: ["desk-run", root.notifyCmd, "load"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var loaded = JSON.parse(data.trim());
                    root.model.clear();
                    if (!Array.isArray(loaded)) return;
                    for (var i = 0; i < loaded.length && i < root.maxCount; i++) {
                        var item = loaded[i] || {};
                        var ts = Number(item.timestamp);
                        if (!isFinite(ts) || ts <= 0) ts = Date.now() - i * 1000;
                        root.model.append({
                            "id": item.id !== undefined ? item.id : ts + i,
                            "appName": item.appName || "System",
                            "summary": item.summary || "新通知",
                            "body": item.body || "",
                            "imagePath": item.imagePath || "",
                            "desktopEntry": item.desktopEntry || "",
                            "timestamp": ts,
                            "time": item.time || Qt.formatTime(new Date(ts), "HH:mm")
                        });
                    }
                } catch(e) {
                    console.log("Failed to load notifications:", e);
                }
            }
        }
    }

    property var saveProcess: Process {
        command: ["desk-run", root.notifyCmd, "save", "[]"]
    }

    function requestSave() {
        saveTimer.restart();
    }

    property var saveTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            var data = [];
            for (var i = 0; i < root.model.count; i++) {
                data.push(root.model.get(i));
            }
            var jsonStr = JSON.stringify(data);
            root.saveProcess.command = ["desk-run", root.notifyCmd, "save", jsonStr];
            root.saveProcess.running = true;
        }
    }

    // ============================================================
    // 供 Manager 调用的数据写入接口
    // ============================================================
    function addRecord(id, appName, summary, body, finalImage, desktopEntry) {
        // freedesktop notification id 可能表示“替换旧通知”，避免历史中出现重复项。
        for (var i = root.model.count - 1; i >= 0; i--) {
            if (String(root.model.get(i).id) === String(id)) root.model.remove(i);
        }

        var now = Date.now();
        root.model.insert(0, {
            "id": id,
            "appName": appName || "System",
            "summary": summary,
            "body": body,
            "imagePath": finalImage,
            "desktopEntry": desktopEntry || "",
            "timestamp": now,
            "time": Qt.formatTime(new Date(now), "HH:mm")
        });
        
        if (root.model.count > root.maxCount) {
            root.model.remove(root.model.count - 1);
        }
        
        root.requestSave(); 
    }

    function clear() {
        model.clear();
        requestSave(); 
    }

    function remove(index) {
        if (index >= 0 && index < model.count) {
            model.remove(index);
            requestSave(); 
        }
    }

    function removeById(id) {
        for (var i = 0; i < model.count; i++) {
            if (String(model.get(i).id) === String(id)) {
                remove(i);
                return true;
            }
        }
        return false;
    }
}
