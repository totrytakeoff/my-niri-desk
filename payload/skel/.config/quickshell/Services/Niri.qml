pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}
    
    // 自定义信号：通知 UI 窗口池已更新
    signal windowsUpdated()

    function updateWorkspaces(workspacesEvent) {
        const workspaceList = workspacesEvent.workspaces;
        workspaceList.sort((a, b) => a.idx - b.idx);
        
        workspaces.clear();
        for (let i = 0; i < workspaceList.length; i++) {
            const workspace = workspaceList[i];
            workspaces.append({
                wsId: String(workspace.id), 
                idx: workspace.idx,
                isActive: workspace.is_active,
                name: workspace.name || "", 
                output: workspace.output || ""
            });
        }
    }

    function activateWorkspace(workspacesEvent) {
        const activeId = String(workspacesEvent.id);
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            const isNowActive = (item.wsId === activeId);
            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
    }

    // 更新全局窗口池并广播信号
    function updateWindows(windowListArray) {
        if (!windowListArray) return;
        windows.clear();
        for (let i = 0; i < windowListArray.length; i++) {
            const win = windowListArray[i];
            windows.append({
                winId: String(win.id),
                title: win.title || "Unknown",
                appId: win.app_id || "unknown",
                workspaceId: String(win.workspace_id) || "",
                isFocused: win.is_focused || false
            });
        }
        windowsUpdated(); // 发射更新信号！
    }

    // 【抓取引擎】：瞬间拉取当前全量窗口状态
    Process {
        id: niriWindowsFetcher
        running: true // 启动时主动抓取一次
        command: ["niri", "msg", "-j", "windows"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const winList = JSON.parse(data.trim());
                    updateWindows(winList);
                } catch (e) {}
            }
        }
    }

    function reloadWindows() {
        // 命令抓取引擎再跑一次
        niriWindowsFetcher.running = true;
    }

    // 【监听引擎】：死盯着 Niri 的底层脉搏
    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    if (event.WorkspacesChanged) {
                        updateWorkspaces(event.WorkspacesChanged);
                    } 
                    else if (event.WorkspaceActivated) {
                        activateWorkspace(event.WorkspaceActivated);
                    }
                    // 【灵魂核心】：精确拦截原子事件。只要有风吹草动，直接触发全量刷新！
                    else if (event.WindowOpenedOrChanged || event.WindowClosed || event.WindowFocusChanged) {
                        reloadWindows();
                    }
                } catch (e) {
                    console.log("Niri Event Error:", e);
                }
            }
        }
    }
}
