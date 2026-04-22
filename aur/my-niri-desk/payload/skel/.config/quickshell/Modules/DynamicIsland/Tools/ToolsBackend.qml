import QtQuick
import Quickshell.Io

Item {
    id: backendRoot

    // Tools 后端
    // -----------------------------------------------------------------------
    // 这个文件不负责画 UI，只负责：
    // 1. 检查工具依赖是否存在
    // 2. 把“某个按钮点击”映射成真实外部命令
    //
    // 目前这层工具的哲学是：
    // - 能直接用成熟外部工具就直接调用
    // - 不在 QuickShell 里重新实现一遍
    //
    // 当前对应关系：
    // - 取色器 -> hyprpicker
    // - 普通截屏 -> grim + slurp + wl-copy
    // - 截长屏 -> wayscrollshot
    // - OCR -> ~/.config/niri/scripts/screenshot-ocr.sh
    // - 录屏/GIF/录音 -> scripts/record.sh
    
    property string currentRecordMode: "video" 
    signal recordCancelled() 

    property bool colorPickerAvailable: false
    property bool screenshotAvailable: false
    property bool longScreenshotAvailable: false
    property bool ocrAvailable: false
    property bool recordAvailable: false
    property bool audioRecordAvailable: false

    // 重新探测外部命令能力。
    function refreshCapabilities() {
        capabilityCheck.running = false
        capabilityCheck.running = true
    }

    function pickColor() { colorPickerProcess.running = false; colorPickerProcess.running = true }
    function takeScreenshot() { screenshotProcess.running = false; screenshotProcess.running = true }
    function takeLongScreenshot() { longScreenshotProcess.running = false; longScreenshotProcess.running = true }
    function runOcr() { ocrProcess.running = false; ocrProcess.running = true }

    // 录屏/GIF 开始：全部统一走 record.sh。
    function startRecord(mode) {
        backendRoot.currentRecordMode = mode
        recordProcess.command = ["bash", "-c", "nohup bash $HOME/.config/quickshell/scripts/record.sh start " + mode + " >/dev/null 2>&1 &"]
        recordProcess.running = false
        recordProcess.running = true
    }

    // 录屏/GIF 停止。
    function stopRecord() {
        var mode = backendRoot.currentRecordMode
        stopProcess.command = ["bash", "-c", "nohup bash $HOME/.config/quickshell/scripts/record.sh stop " + mode + " >/dev/null 2>&1 &"]
        stopProcess.running = false
        stopProcess.running = true
    }

    // 录音开始：mode 为 audio_mic / audio_sys。
    function startAudio(mode) {
        startAudioProcess.command = ["bash", "-c", "nohup bash $HOME/.config/quickshell/scripts/record.sh start " + mode + " >/dev/null 2>&1 &"]
        startAudioProcess.running = false
        startAudioProcess.running = true
    }

    // 录音停止时统一传 audio。
    function stopAudio() {
        stopAudioProcess.command = ["bash", "-c", "nohup bash $HOME/.config/quickshell/scripts/record.sh stop audio >/dev/null 2>&1 &"]
        stopAudioProcess.running = false
        stopAudioProcess.running = true
    }

    Component.onCompleted: refreshCapabilities()

    Process {
        id: capabilityCheck
        command: ["bash", "-lc", "printf 'hyprpicker=%s\\n' \"$(command -v hyprpicker >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'grim=%s\\n' \"$(command -v grim >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'slurp=%s\\n' \"$(command -v slurp >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'wlcopy=%s\\n' \"$(command -v wl-copy >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'wayscrollshot=%s\\n' \"$(command -v wayscrollshot >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'tesseract=%s\\n' \"$(command -v tesseract >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'wfrecorder=%s\\n' \"$(command -v wf-recorder >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'ffmpeg=%s\\n' \"$(command -v ffmpeg >/dev/null 2>&1 && echo 1 || echo 0)\"; printf 'pactl=%s\\n' \"$(command -v pactl >/dev/null 2>&1 && echo 1 || echo 0)\""]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const line = data.trim()
                if (!line || line.indexOf("=") === -1) return
                const parts = line.split("=")
                const key = parts[0]
                const ok = parts[1] === "1"
                if (key === "hyprpicker") backendRoot.colorPickerAvailable = ok
                else if (key === "grim") backendRoot.screenshotAvailable = ok && backendRoot.screenshotAvailable
                else if (key === "slurp") backendRoot.screenshotAvailable = ok && backendRoot.screenshotAvailable
                else if (key === "wlcopy") backendRoot.screenshotAvailable = ok && backendRoot.screenshotAvailable
                else if (key === "wayscrollshot") backendRoot.longScreenshotAvailable = ok
                else if (key === "tesseract") backendRoot.ocrAvailable = ok && backendRoot.ocrAvailable
                else if (key === "wfrecorder") backendRoot.recordAvailable = ok && backendRoot.recordAvailable
                else if (key === "ffmpeg") {
                    backendRoot.recordAvailable = ok && backendRoot.recordAvailable
                    backendRoot.audioRecordAvailable = ok && backendRoot.audioRecordAvailable
                } else if (key === "pactl") backendRoot.audioRecordAvailable = ok && backendRoot.audioRecordAvailable
            }
        }
        onStarted: {
            backendRoot.screenshotAvailable = true
            backendRoot.ocrAvailable = true
            backendRoot.recordAvailable = true
            backendRoot.audioRecordAvailable = true
        }
    }

    // 简单工具保持内联调用，避免额外脚本层级。
    Process { id: colorPickerProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; hyprpicker -a' >/dev/null 2>&1 &"] }
    Process { id: screenshotProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; grim -g \"$(slurp)\" - | wl-copy' >/dev/null 2>&1 &"] }
    Process { id: longScreenshotProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; wayscrollshot' >/dev/null 2>&1 &"] }
    Process { id: ocrProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; bash $HOME/.config/niri/scripts/screenshot-ocr.sh >/tmp/quickshell-ocr.log 2>&1' >/dev/null 2>&1 &"] }
    
    Process { id: recordProcess }
    Process { id: stopProcess }

    // 【新增：录音专用的 Process 节点】
    Process { id: startAudioProcess }
    Process { id: stopAudioProcess }
}
