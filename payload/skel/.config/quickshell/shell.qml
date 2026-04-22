// QuickShell 根入口
// ---------------------------------------------------------------------------
// 这是整套桌面 shell 的装配文件，相当于“总开关”。
//
// 它负责把各大模块挂到同一个 ShellRoot 里：
// - 顶栏 Bar
// - 灵动岛 DynamicIsland
// - 左侧 sidebar
// - 右侧快捷设置
// - 右下通知角
// - 锁屏 / 启动器的 IPC 入口
//
// 你后面如果要“整体裁掉一个功能”，最先看的通常就是这个文件。
//
// 常见排错：
// 1. QuickShell 整体起不来：先看这里 import 的模块路径是否正确。
// 2. 某个组件完全不显示：先确认这里有没有实例化。
// 3. 某个快捷键调 IPC 没反应：先确认这里是否注册了对应 target。
//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io  
import QtQuick        
import qs.Modules.Bar
import qs.Modules.Launcher 
import qs.Modules.DynamicIsland
// 【新增】：引入你重构后的 Widget 文件夹
import qs.Widget
// 【新增】：引入热角触发器路径
import "./Widget/left_sidebar"
import "./Modules/HotCorner"

ShellRoot {
    // 顶栏：工作区 / 当前窗口 / 系统指标 / tray / 右侧快捷入口。
    Bar {}
    
    // 灵动岛：瞬时状态、控制中心、通知、媒体、工具、壁纸。
    DynamicIsland {}

    // 热角全局控制 IPC。
    // 这里不负责真正的热角检测，只负责暴露启停接口给 niri / 快捷键 / 调试命令。
    IpcHandler {
        target: "hotcorner"
        
        // 【核心修复】：为 IPC 参数加上严格的类型注解 ': bool'
        function setEnabled(code: bool) {
            WidgetState.hotCornerEnabled = code
            return `HotCorner set to: ${code}`
        }
        
        // 信号：切换热角状态
        function toggle() {
            WidgetState.hotCornerEnabled = !WidgetState.hotCornerEnabled
            return `HotCorner toggled to: ${WidgetState.hotCornerEnabled}`
        }
    }

    // 左侧 companion sidebar：总览 / 进程 / 会话。
    LeftSidebarWindow {}

    // 右侧快捷设置：Network / Bluetooth / Audio。
    // 它本身是独立 overlay 窗口；这里只负责挂载根组件。
    RightSidebar {}

    // 热角检测器：右下角 invisible detector。
    HotCornerDetectorWindow {}
    
    // 独立通知角：固定在右下角的通知历史面板。
    NotificationCornerWindow {}

    // 锁屏 Loader。
    // 平时不加载，收到 IPC `lock.open()` 后才创建锁屏模块。
    Loader { id: lockLoader; active: false; source: "Modules/Lock/Lock.qml"
        Connections { target: lockLoader.item; ignoreUnknownSignals: true; function onUnlocked() { lockLoader.active = false } }
    }
    IpcHandler { target: "lock"; function open() { if (!lockLoader.active) { lockLoader.active = true; return "LOCKED" } return "ALREADY_LOCKED" } }

    // 启动器窗口。
    LauncherWindow { id: rofiLauncher }
    IpcHandler { target: "launcher"; function toggle() { rofiLauncher.toggleWindow(); return "LAUNCHER_TOGGLED"; } }
}
