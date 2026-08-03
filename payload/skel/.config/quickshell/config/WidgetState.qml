import QtQuick
import Quickshell
pragma Singleton

QtObject {
    // 全局 UI 状态中心
    // -----------------------------------------------------------------------
    // 这份文件非常关键。它不负责画界面，而是负责保存“当前桌面各层 UI 处于什么状态”。
    // 可以把它理解成轻量全局 store：
    // - 右侧快捷设置现在开没开
    // - 左侧 sidebar 当前在哪一页
    // - 通知中心是否 pinned
    // - 当前通知视图是 main/detail/all
    // - 热角是否启用
    // 通知正文由 NotificationStore 统一持久化；这里仅维护分类索引和 UI 状态。

    id: root

    property bool qsOpen: false
    // 右侧快捷设置当前视图。
    // 当前规划：
    // - network: 网络连接与 Wi-Fi 管理
    // - bluetooth: 蓝牙电源、设备列表、连接/断开
    // - audio: 输出/输入与应用音量
    property string qsView: "network"
    // 会话锁的真实状态由 WlSessionLock.secure 回写。
    // lockPending 只表示已经提出请求，不能当作会话已经安全锁定。
    property bool sessionLocked: false
    property bool lockPending: false
    property string lockReason: "manual"
    // 左侧边栏状态
    property bool leftSidebarOpen: false
    // companion sidebar 的三页职责：
    // - dashboard: 压缩后的总览信息与资源块
    // - processes: 轻量进程管理
    // - session: 当前会话/设备状态
    property string leftSidebarView: "dashboard"
    // Launcher 键盘循环导航总开关。
    // 打开后：
    // - 应用 / 窗口 / 壁纸列表支持首尾循环选择
    // - Tab / Shift+Tab 支持在 3 个 launcher 页面间循环切换
    // 关闭后则回退为普通边界行为：到顶/到底停止，Tab 只做正向切换。
    property bool launcherCyclicNavigation: true
    // Launcher 应用排序模式: "alphabetical" | "frequent"
    property string launcherSortMode: "alphabetical"
    // Launcher 页面布局模式: "list" | "grid"
    property string launcherLayoutMode: "list"
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
    // 设置每个 App 在通知中心最多展示的历史消息数量。
    property int maxMessagesPerApp: 50
    // 右下角通知热角是否启用。
    property bool hotCornerEnabled: true
    // 每个应用当前剩余多少条通知。
    property var notifAppCounts: {
        "system": 0,
        "qq": 0,
        "wechat": 0,
        "telegram": 0,
        "discord": 0
    }
    // 每个应用的通知列表。
    property var notifMessages: {
        "system": [],
        "qq": [],
        "wechat": [],
        "telegram": [],
        "discord": []
    }
    property var notificationStoreConnections

    // 统一打开右侧快捷设置，并通知灵动岛释放自身交互层。
    signal closeIslandRequested()
    signal lockRequested()
    signal notifDataChanged()

    function requestLock(reason) {
        lockReason = reason || "manual";
        if (sessionLocked || lockPending)
            return ;

        lockPending = true;
        lockRequested();
    }

    function confirmLockSecure() {
        sessionLocked = true;
        lockPending = false;
    }

    function cancelLockRequest() {
        if (sessionLocked)
            return ;

        lockPending = false;
        lockReason = "manual";
    }

    function confirmUnlocked() {
        sessionLocked = false;
        lockPending = false;
        lockReason = "manual";
    }

    function openQuickSettings(viewId) {
        qsView = viewId;
        qsOpen = true;
        closeIslandRequested();
    }

    function toggleQuickSettings(viewId) {
        if (qsOpen && qsView === viewId) {
            qsOpen = false;
            return ;
        }
        openQuickSettings(viewId);
    }

    function openNotifPanelFromHotCorner() {
        if (hotCornerEnabled && !notifOpen)
            notifOpen = true;

    }

    function appIdForRecord(item) {
        var name = ((item.appName || "") + " " + (item.desktopEntry || "") + " " + (item.summary || "")).toLowerCase();
        if (name.indexOf("qq") !== -1 || name.indexOf("tencent") !== -1)
            return "qq";

        if (name.indexOf("wechat") !== -1 || name.indexOf("微信") !== -1)
            return "wechat";

        if (name.indexOf("telegram") !== -1)
            return "telegram";

        if (name.indexOf("discord") !== -1)
            return "discord";

        return "system";
    }

    function rebuildNotificationIndex() {
        var nextMessages = {
            "system": [],
            "qq": [],
            "wechat": [],
            "telegram": [],
            "discord": []
        };
        var nextCounts = {
            "system": 0,
            "qq": 0,
            "wechat": 0,
            "telegram": 0,
            "discord": 0
        };
        for (var i = 0; i < NotificationStore.model.count; i++) {
            var item = NotificationStore.model.get(i);
            var appId = appIdForRecord(item);
            if (nextMessages[appId].length >= maxMessagesPerApp)
                continue;

            var ts = Number(item.timestamp);
            if (!isFinite(ts) || ts <= 0)
                ts = Date.now() - i * 1000;

            nextMessages[appId].push({
                "id": item.id,
                "title": item.summary || item.appName || "新通知",
                "body": item.body || "",
                "timestamp": ts,
                "appId": appId
            });
            nextCounts[appId]++;
        }
        notifMessages = nextMessages;
        notifAppCounts = nextCounts;
        notifDataChanged();
    }

    function dismissMessage(appId, messageId) {
        var wasLastForApp = !notifAppCounts[appId] || notifAppCounts[appId] <= 1;
        NotificationStore.removeById(messageId);
        if (wasLastForApp)
            notifCurrentView = "main";

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

    Component.onCompleted: rebuildNotificationIndex()

    notificationStoreConnections: Connections {
        function onCountChanged() {
            root.rebuildNotificationIndex();
        }

        target: NotificationStore.model
    }

}
