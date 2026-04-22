import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.PowerButton
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings

// 顶栏根模块
// ---------------------------------------------------------------------------
// 这层只负责：
// - 为每块屏幕创建一个顶栏 PanelWindow
// - 左边放工作区 + 当前窗口
// - 右边放 tray + 系统指标 + 快捷设置入口
//
// 如果以后你要改：
// - 顶栏总高度
// - 左右布局顺序
// - 哪些模块出现在哪边
// 优先改这个文件。

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData

        anchors { left: true; top: true; right: true }
        color: "transparent"
        
        property real barHeight: 52
        
        // 顶栏是固定高度，不跟随灵动岛展开/收起而变化。
        implicitHeight: barWindow.barHeight
        
        // 给 compositor 预留顶栏高度，避免平铺窗口顶到 bar 下面。
        exclusiveZone: barHeight
        
        WlrLayershell.layer: WlrLayer.Top

        // 内容容器：仅负责左右排版。
        Item {
            id: barContent
            
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: barWindow.barHeight 

            // 左侧：导航与上下文。
            RowLayout {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 10

                Workspaces {}
                ActiveWindow {}
                
            }

            // 右侧：状态与轻交互入口。
            RowLayout {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 10

                Tray {}
                SysMonitor { Layout.alignment: Qt.AlignVCenter }
                

                QuickSettings { Layout.alignment: Qt.AlignVCenter }
                
                
            }
        }
    }
}
