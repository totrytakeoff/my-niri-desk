import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse
    
    implicitHeight: 36
    
    // 【修复点 1】使用标准的 JavaScript 函数块来处理宽度，彻底避免三元运算符解析崩溃
    implicitWidth: {
        if (isHovered) {
            return contentLayout.implicitWidth + 24;
        }
        return collapsedGroup.implicitWidth + 24;
    }

    Behavior on implicitWidth { 
        NumberAnimation { duration: 300; easing.type: Easing.OutQuart } 
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Colorscheme.glass_bar
        radius: height / 2 
        visible: false 
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
    }

    // ================= 数据源 =================
    property string ramText: "..."
    property string cpuText: "0%"
    property string tempText: "0°C"
    property string diskText: "0%"
    property string collapsedMetric: Sizes.collapsedSysMetric

    function collapsedIcon() {
        if (collapsedMetric === "cpu") return "";
        if (collapsedMetric === "temp") return "";
        if (collapsedMetric === "disk") return "";
        return "";
    }

    function collapsedColor() {
        if (collapsedMetric === "cpu") return "#cba6f7";
        if (collapsedMetric === "temp") return "#f9e2af";
        if (collapsedMetric === "disk") return "#89b4fa";
        return "#a6e3a1";
    }

    function collapsedText() {
        if (collapsedMetric === "cpu") return root.cpuText;
        if (collapsedMetric === "temp") return root.tempText;
        if (collapsedMetric === "disk") return root.diskText;
        return root.ramText;
    }

    function collapsedLabel() {
        if (collapsedMetric === "cpu") return "CPU";
        if (collapsedMetric === "temp") return "Temperature";
        if (collapsedMetric === "disk") return "Disk";
        return "Memory";
    }

    // 【修复点 2】将字符串拼接提前提取为变量，禁止在 command 数组中直接做加法
    property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/sys_monitor.py"

    Process {
        id: proc
        // 干净的数组引用，不会再出现缺少逗号的报错
        command: ["python3", root.scriptPath]
        
        stdout: SplitParser {
            // 【修复点 3】使用标准 function 语法，避免箭头函数 => 造成的兼容性误判
            onRead: function(data) {
                try {
                    let json = JSON.parse(data.trim());
                    root.ramText = json.ram.text;
                    root.cpuText = json.cpu.text;
                    root.tempText = json.temp.text;
                    root.diskText = json.disk.text;
                } catch(e) {
                    console.log("SysMonitor JSON Error: " + e)
                }
            }
        }
    }

    // 【修复点 4】规范化属性换行
    Timer { 
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    // ================= 布局内容 =================
    RowLayout {
        id: contentLayout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        spacing: 12
        layoutDirection: Qt.RightToLeft

        // --- 1. Collapsed metric (configurable) ---
        RowLayout {
            id: collapsedGroup
            spacing: 4
            Text { 
                text: root.collapsedIcon()
                color: root.collapsedColor()
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: root.collapsedText()
                color: Colorscheme.on_surface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 2. Disk (展开) ---
        RowLayout {
            id: diskGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: "#89b4fa" 
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: root.diskText
                color: Colorscheme.on_surface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 3. Temp (展开) ---
        RowLayout {
            id: tempGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: "#f9e2af" 
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: root.tempText
                color: Colorscheme.on_surface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // --- 4. CPU (展开) ---
        RowLayout {
            id: cpuGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: "#cba6f7" 
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 16
            }
            Text { 
                text: root.cpuText
                color: Colorscheme.on_surface
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 13
            }
        }
    }

    // ================= 交互区域 =================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            proc.running = true; 
        }
        
        // QML 隐式自带 mouse 变量，直接使用即可
        onPressed: {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["gnome-system-monitor"]);
            }
        }
    }

    HoverTag {
        open: mouseArea.containsMouse
        text: root.isHovered
            ? "Collapsed: " + root.collapsedLabel() + " | Right click: system monitor"
            : "Collapsed: " + root.collapsedLabel()
    }
}
