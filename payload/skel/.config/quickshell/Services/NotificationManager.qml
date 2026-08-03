pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Modules.DynamicIsland.OverviewContent 
import qs.config 

Item {
    id: root

    property alias model: popupList           
    property bool hasNotifs: popupList.count > 0 
    
    ListModel { id: popupList }

    NotificationServer {
        id: server
        
        onNotification: (n) => {
            const desktopEntry = (n.desktopEntry || "").toLowerCase();
            if (desktopEntry === "spotify" || desktopEntry.includes("player")) return;

            const imApps = [
                "qq", "com.tencent.qq", "linuxqq",
                "wechat", "com.tencent.wechat", "electronic-wechat",
                "telegram", "org.telegram.desktop", "telegram-desktop",
                "discord", "slack", "element"
            ];

            let appNameLower = (n.desktopEntry || n.appName || "").toLowerCase();
            const isIMApp = imApps.includes(appNameLower) || 
                            appNameLower.includes("qq") || 
                            appNameLower.includes("wechat") || 
                            appNameLower.includes("telegram") || 
                            appNameLower.includes("discord");

            let finalImage = "";
            let homePath = Quickshell.env("HOME") || "/home/archirithm";

            if (appNameLower.includes("qq")) {
                finalImage = "file://" + homePath + "/.config/quickshell/assets/apps/qq.svg";
            } else if (appNameLower.includes("wechat")) {
                finalImage = "file://" + homePath + "/.config/quickshell/assets/apps/wechat.svg";
            } else if (appNameLower.includes("discord")) {
                finalImage = "file://" + homePath + "/.config/quickshell/assets/apps/discord.svg";
            } else if (appNameLower.includes("telegram")) {
                finalImage = "file://" + homePath + "/.config/quickshell/assets/apps/telegram.svg";
            } else if (!isIMApp && n.image && (n.image.startsWith("/") || n.image.startsWith("file://"))) {
                finalImage = n.image.startsWith("/") ? "file://" + n.image : n.image;
            } else {
                let iconName = n.appIcon || n.desktopEntry || n.icon || "";
                if (iconName !== "") {
                    if (iconName.startsWith("/") || iconName.startsWith("file://")) {
                        finalImage = iconName.startsWith("/") ? "file://" + iconName : iconName;
                    } else {
                        finalImage = "icon:" + iconName;
                    }
                }
            }

            let currentTime = new Date().toLocaleTimeString(Qt.locale(), "HH:mm");

            NotificationStore.addRecord(n.id, n.appName, n.summary, n.body, finalImage, n.desktopEntry);

            let notifData = {
                "notifId": n.id,
                "summary": n.summary,
                "body": n.body,
                "imagePath": finalImage,
                "time": currentTime
            };

            if (!ControlBackend.dndEnabled) {
                // 相同 freedesktop id 表示替换通知；弹窗队列也保持单份。
                root.removeByNotifId(n.id);
                popupList.insert(0, notifData);
                if (popupList.count > 3) popupList.remove(3);
            }
        }
    }

    function removeByNotifId(targetId) {
        for (let i = 0; i < popupList.count; i++) {
            if (popupList.get(i).notifId === targetId) {
                popupList.remove(i);
                break;
            }
        }
    }
    
}
