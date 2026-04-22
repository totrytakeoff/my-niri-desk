import QtQuick
import QtQuick.Layouts
import QtQuick.Window 
import qs.config
import qs.Widget.common

Item {
    id: toolsRoot

    // Tools 前端
    // -----------------------------------------------------------------------
    // 这层只负责：
    // - 展示工具按钮
    // - 键盘/鼠标选中
    // - 根据后端 capability 决定是否可点
    // - hover 提示说明缺失依赖
    //
    // 真正的执行命令都在 ToolsBackend.qml。

    ToolsBackend {
        id: toolsBackend
        
        // 【核心修复】：接收后端发来的 ESC 取消信号，并关闭主岛的录像状态
        onRecordCancelled: {
            console.log("用户按下了 ESC，取消了录制选区。")
            toolsRoot.requestSetRecording(false)
        }
    }

    // 预留给外部监听的关闭信号
    signal requestHideIsland()
    // 向 DynamicIsland 发送录制状态变更信号
    signal requestSetRecording(bool state)
    signal requestShowAudio(string mode)

    // Tools 面板的按钮模型。
    // 顺序和 selectedIndex/triggerSelected 的分支保持一致。
    property var toolsModel: [
        { icon: "colorize",         tip: "取色器" },
        { icon: "videocam",         tip: "录屏" },        
        { icon: "gif",              tip: "录制 GIF" },    
        { icon: "crop_free",        tip: "普通截屏" },
        { icon: "height",           tip: "截长屏" },
        { icon: "document_scanner", tip: "OCR 识别" },
        { icon: "mic",              tip: "录麦克风" },       // 索引 6
        { icon: "speaker",          tip: "录电脑声音" }      // 【新增】：索引 7
    ]

    property int selectedIndex: 0

    focus: visible
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            forceActiveFocus(); 
        }
    }

    Keys.onLeftPressed: {
        selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length
    }
    
    Keys.onRightPressed: {
        selectedIndex = (selectedIndex + 1) % toolsModel.length
    }
    
    Keys.onReturnPressed: triggerSelected()
    Keys.onEnterPressed: triggerSelected()

    // 按 index 返回某个工具当前是否可用。
    function toolAvailable(index) {
        if (index === 0) return toolsBackend.colorPickerAvailable
        if (index === 1 || index === 2) return toolsBackend.recordAvailable
        if (index === 3) return toolsBackend.screenshotAvailable
        if (index === 4) return toolsBackend.longScreenshotAvailable
        if (index === 5) return toolsBackend.ocrAvailable
        if (index === 6 || index === 7) return toolsBackend.audioRecordAvailable
        return false
    }

    // hover 提示：可用时显示正常名称，不可用时显示缺失依赖。
    function toolTip(index) {
        if (toolAvailable(index)) return toolsModel[index].tip
        if (index === 0) return "取色器（未安装 hyprpicker）"
        if (index === 1 || index === 2) return toolsModel[index].tip + "（缺少 wf-recorder/ffmpeg）"
        if (index === 3) return "普通截屏（缺少 grim/slurp/wl-copy）"
        if (index === 4) return "截长屏（未安装 wayscrollshot）"
        if (index === 5) return "OCR 识别（缺少 tesseract）"
        if (index === 6 || index === 7) return toolsModel[index].tip + "（缺少 ffmpeg/pactl）"
        return toolsModel[index].tip + "（不可用）"
    }

    function triggerSelected() {
        // 不可用工具直接拒绝，不让 UI 看起来像“点了没反应”。
        if (!toolAvailable(selectedIndex)) {
            console.log("工具当前不可用: " + toolTip(selectedIndex))
            return
        }
        console.log("触发工具: " + toolsModel[selectedIndex].tip)
        
        toolsRoot.requestHideIsland()
        
        if (selectedIndex === 0) {
            toolsBackend.pickColor()
        } else if (selectedIndex === 1) { // 录屏
            toolsRoot.requestSetRecording(true)
            toolsBackend.startRecord("video")
        } else if (selectedIndex === 2) { // 录制 GIF
            toolsRoot.requestSetRecording(true)
            toolsBackend.startRecord("gif")
        } else if (selectedIndex === 3) {
            toolsBackend.takeScreenshot()
        } else if (selectedIndex === 4) {
            toolsBackend.takeLongScreenshot()
        } else if (selectedIndex === 5) {
            toolsBackend.runOcr()
        } else if (selectedIndex === 6) { // 录音 - 麦克风
            toolsRoot.requestShowAudio("mic")
            toolsBackend.startAudio("audio_mic")
        } else if (selectedIndex === 7) { // 录音 - 系统声音
            toolsRoot.requestShowAudio("sys")
            toolsBackend.startAudio("audio_sys")
        } else {
            console.log("该工具的后端尚未实现！")
        }
    }

    // 【核心修复】：保留唯一的一个停止录制接口
    function stopRecording() {
        toolsBackend.stopRecord()
    }
    function stopAudio() {
        toolsBackend.stopAudio()
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: toolsRoot.toolsModel

            Rectangle {
                width: 48
                height: 48
                radius: 12
                property bool available: toolsRoot.toolAvailable(index)
                
                color: (toolsMouse.containsMouse || index === toolsRoot.selectedIndex) 
                    ? Colorscheme.surface_variant : "transparent"
                opacity: available ? 1.0 : 0.42
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: "Material Symbols Rounded" 
                    font.pixelSize: 22
                    color: available ? Colorscheme.on_surface : Colorscheme.on_surface_variant
                }

                MouseArea {
                    id: toolsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    
                    onEntered: {
                        if (parent.available) toolsRoot.selectedIndex = index
                    }

                    onClicked: {
                        if (!parent.available) return
                        toolsRoot.selectedIndex = index
                        toolsRoot.triggerSelected()
                    }
                }

                HoverTag {
                    open: toolsMouse.containsMouse
                    text: toolsRoot.toolTip(index)
                }
            }
        }
    }
}
