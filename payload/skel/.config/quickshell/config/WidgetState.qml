pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root 

    // 全局 UI 状态中心
    // -----------------------------------------------------------------------
    // 这份文件非常关键。它不负责画界面，而是负责保存“当前桌面各层 UI 处于什么状态”。
    //
    // 可以把它理解成轻量全局 store：
    // - 右侧快捷设置现在开没开
    // - 左侧 sidebar 当前在哪一页
    // - 通知中心是否 pinned
    // - 当前通知视图是 main/detail/all
    // - 热角是否启用
    //
    // 另外它还顺手承担了通知数据持久化和内存状态管理。

    property bool qsOpen: false
    // 右侧快捷设置当前视图。
    // 当前规划：
    // - network: 网络连接与 Wi-Fi 管理
    // - bluetooth: 蓝牙电源、设备列表、连接/断开
    // - audio: 输出/输入与应用音量
    property string qsView: "network"

    // 左侧边栏状态
    property bool leftSidebarOpen: false
    // companion sidebar 的三页职责：
    // - dashboard: 压缩后的总览信息与资源块
    // - processes: 轻量进程管理
    // - session: 当前会话/设备状态
    property string leftSidebarView: "dashboard"

    // 通知中心窗口是否打开。
    property bool notifOpen: false
    property bool notifIsHovered: false 
    // 是否被用户固定，不随失焦关闭。
    property bool notifPinned: false 
    // 通知内部的 3 种视图状态：
    // - main: 按应用分组的主视图
    // - detail: 某一个应用的详情
    // - all: 所有通知长列表
    property string notifCurrentView: "main" 
    property string notifDetailAppId: ""
    property string notifDisplayMode: "compact" 

    // 设置每个 App 最多保留的历史消息数量
    property int maxMessagesPerApp: 50

    // 右下角通知热角是否启用。
    property bool hotCornerEnabled: true
    function openNotifPanelFromHotCorner() {
        if (hotCornerEnabled && !notifOpen) {
            notifOpen = true;
        }
    }

    // 每个应用当前剩余多少条通知。
    property var notifAppCounts: {
        "system": 0, "qq": 0, "wechat": 0, "telegram": 0, "discord": 0
    }

    // 每个应用的通知列表。
    property var notifMessages: {
        "system": [], "qq": [], "wechat": [], "telegram": [], "discord": []
    }

    signal notifDataChanged();

    // 通知持久化：所有通知最终都落到 notify_db.py 管理。
    readonly property string dbScriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/notify_db.py"

    property var loadProcess: Process {
        command: ["python3", root.dbScriptPath, "load"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var output = data.trim();
                    if (!output || output === "[]" || output === "{}") return;

                    var loaded = JSON.parse(output);
                    var mockMsgs = { "system": [], "qq": [], "wechat": [], "telegram": [], "discord": [] };
                    var mockCounts = { "system": 0, "qq": 0, "wechat": 0, "telegram": 0, "discord": 0 };

                    if (Array.isArray(loaded)) {
                        for (var i = 0; i < loaded.length; i++) {
                            var item = loaded[i];
                            var aId = "system";

                            var nameStr = (item.appName || "").toLowerCase() + " " + (item.desktopEntry || "").toLowerCase() + " " + (item.summary || "").toLowerCase();
                            if (nameStr.indexOf("qq") !== -1) aId = "qq";
                            else if (nameStr.indexOf("wechat") !== -1 || nameStr.indexOf("微信") !== -1) aId = "wechat";
                            else if (nameStr.indexOf("telegram") !== -1) aId = "telegram";
                            else if (nameStr.indexOf("discord") !== -1) aId = "discord";

                            var ts = item.timestamp || item.time;
                            if (typeof ts === "string" || isNaN(ts)) {
                                ts = Date.now() - i * 1000; 
                            }

                            var notifObj = {
                                id: item.id !== undefined ? item.id : Date.now() + i,
                                title: item.summary || item.appName || "新通知",
                                body: item.body || "",
                                timestamp: ts,
                                appId: aId,
                                _raw: item 
                            };
                            
                            mockMsgs[aId].push(notifObj);
                            mockCounts[aId]++;
                        }
                    }

                    root.notifMessages = mockMsgs;
                    root.notifAppCounts = mockCounts;
                    root.notifDataChanged();
                    console.log("本地通知加载成功！数量: " + loaded.length);
                } catch(e) {
                    console.log("解析通知失败: " + e);
                }
            }
        }
    }

    property var saveProcess: Process {
        command: ["python3", root.dbScriptPath, "save", "[]"] 
    }

    property var saveTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            var all = root.getAllMessages(); 
            var allToSave = [];
            
            for (var i = 0; i < all.length; i++) {
                var m = all[i];
                if (m._raw) {
                    allToSave.push(m._raw);
                } else {
                    var appName = "System";
                    if (m.appId === "qq") appName = "QQ";
                    if (m.appId === "wechat") appName = "WeChat";
                    if (m.appId === "telegram") appName = "Telegram";
                    if (m.appId === "discord") appName = "Discord";
                    
                    allToSave.push({
                        id: m.id,
                        appName: appName,
                        summary: m.title,
                        body: m.body,
                        timestamp: m.timestamp,
                        time: m.timestamp,
                        imagePath: "",
                        desktopEntry: ""
                    });
                }
            }
            
            var jsonStr = JSON.stringify(allToSave);
            root.saveProcess.command = ["python3", root.dbScriptPath, "save", jsonStr];
            root.saveProcess.running = true;
        }
    }

    function requestSave() {
        saveTimer.restart();
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    // 核心 API：给 NotificationManager / UI 组件读写通知数据。
    function addRealNotification(appId, notifData) {
        var mockCounts = JSON.parse(JSON.stringify(notifAppCounts));
        var mockMsgs = JSON.parse(JSON.stringify(notifMessages));
        if (!mockMsgs[appId]) mockMsgs[appId] = []; 
        
        mockMsgs[appId].unshift(notifData);
        
        // 超出上限则剔除最旧消息，避免状态无限膨胀。
        while (mockMsgs[appId].length > maxMessagesPerApp) {
            mockMsgs[appId].pop();
        }

        mockCounts[appId] = mockMsgs[appId].length;

        notifMessages = mockMsgs;
        notifAppCounts = mockCounts;
        notifDataChanged();
        
        requestSave(); 
    }

    function dismissMessage(appId, messageId) {
        var mockCounts = JSON.parse(JSON.stringify(notifAppCounts));
        var mockMsgs = JSON.parse(JSON.stringify(notifMessages));
        
        if (mockMsgs[appId]) {
            mockMsgs[appId] = mockMsgs[appId].filter(function(msg) {
                return msg.id !== messageId;
            });
            mockCounts[appId] = mockMsgs[appId].length;
            
            notifMessages = mockMsgs; 
            notifAppCounts = mockCounts; 
            notifDataChanged();
            
            // 某个应用的消息清空后，自动退回通知主视图。
            if (mockMsgs[appId].length === 0) {
                notifCurrentView = "main";
            } 
            
            requestSave(); 
        }
    }

    function getAllMessages() {
        // 把按 app 存储的消息 flatten 成时间倒序全列表。
        var all = [];
        for (var appId in notifMessages) {
            var msgs = notifMessages[appId];
            if (msgs) {
                for (var i = 0; i < msgs.length; i++) {
                    var msgCopy = JSON.parse(JSON.stringify(msgs[i]));
                    msgCopy.appId = appId; 
                    all.push(msgCopy);
                }
            }
        }
        all.sort(function(a, b) {
            var tA = a.timestamp || 0;
            var tB = b.timestamp || 0;
            return tB - tA; 
        });
        return all;
    }
}
