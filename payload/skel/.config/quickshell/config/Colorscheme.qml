pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // QuickShell 全局配色表
    // -----------------------------------------------------------------------
    // 这份文件是整个桌面视觉语言的核心：
    // - 顶栏
    // - 灵动岛
    // - sidebar
    // - 通知中心
    // - 快捷设置
    // 几乎都会从这里取色。
    //
    // 前半段是 Material 风格的基础色槽；
    // 后半段 `glass_*` 是我们额外派生出来的玻璃层颜色。
    //
    // 重要关系：
    // 1. 壁纸切换会触发 matugen 生成 `~/.cache/quickshell_colors.json`
    // 2. 这个文件会热重载覆盖下面这些基础色
    // 3. `glass_*` 再基于这些基础色做二次表达

    property color background : "#0f1416"
    property color error : "#ffb4ab"
    property color error_container : "#93000a"
    property color inverse_on_surface : "#2c3134"
    property color inverse_primary : "#09677f"
    property color inverse_surface : "#dee3e6"
    property color on_background : "#dee3e6"
    property color on_error : "#690005"
    property color on_error_container : "#ffdad6"
    property color on_primary : "#003544"
    property color on_primary_container : "#b8eaff"
    property color on_primary_fixed : "#001f28"
    property color on_primary_fixed_variant : "#004d61"
    property color on_secondary : "#1e333c"
    property color on_secondary_container : "#cfe6f1"
    property color on_secondary_fixed : "#071e26"
    property color on_secondary_fixed_variant : "#354a53"
    property color on_surface : "#dee3e6"
    property color on_surface_variant : "#bfc8cc"
    property color on_tertiary : "#2c2d4d"
    property color on_tertiary_container : "#e1e0ff"
    property color on_tertiary_fixed : "#171837"
    property color on_tertiary_fixed_variant : "#434465"
    property color outline : "#8a9296"
    property color outline_variant : "#40484c"
    property color primary : "#88d0ec"
    property color primary_container : "#004d61"
    property color primary_fixed : "#b8eaff"
    property color primary_fixed_dim : "#88d0ec"
    property color scrim : "#000000"
    property color secondary : "#b3cad5"
    property color secondary_container : "#354a53"
    property color secondary_fixed : "#cfe6f1"
    property color secondary_fixed_dim : "#b3cad5"
    property color shadow : "#000000"
    property color source_color : "#669cb1"
    property color surface : "#0f1416"
    property color surface_bright : "#353a3d"
    property color surface_container : "#1b2023"
    property color surface_container_high : "#252b2d"
    property color surface_container_highest : "#303638"
    property color surface_container_low : "#171c1f"
    property color surface_container_lowest : "#0a0f11"
    property color surface_dim : "#0f1416"
    property color surface_tint : "#88d0ec"
    property color surface_variant : "#40484c"
    property color tertiary : "#c3c3eb"
    property color tertiary_container : "#434465"
    property color tertiary_fixed : "#e1e0ff"
    property color tertiary_fixed_dim : "#c3c3eb"
    // 玻璃层专用颜色。
    // 这里不是 matugen 直接给的原始字段，而是“基于基础色二次派生”的。
    // 之前灵动岛发黑，主因就是这里的玻璃层取色过深。
    property color glass_bar : Qt.rgba(inverse_surface.red, inverse_surface.green, inverse_surface.blue, 0.22)
    property color glass_bar_hover : Qt.rgba(inverse_surface.red, inverse_surface.green, inverse_surface.blue, 0.30)
    property color glass_button : Qt.rgba(inverse_surface.red, inverse_surface.green, inverse_surface.blue, 0.16)
    property color glass_card : Qt.rgba(inverse_surface.red, inverse_surface.green, inverse_surface.blue, 0.26)
    property color glass_island : Qt.rgba(inverse_surface.red, inverse_surface.green, inverse_surface.blue, 0.20)
    property color glass_outline : Qt.alpha(inverse_surface, 0.24)

    // 当前壁纸预览图，供 launcher / wallpapers 模块读取。
    property string currentWallpaperPreview: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"

    // 热重载引擎：监听 matugen 产物。
    // 如果文件变化，就把新颜色覆盖进当前 Singleton。
    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.cache/quickshell_colors.json"
        watchChanges: true 

        onLoaded: {
            try {
                const text = colorFile.text();
                if (!text) return;
                
                const newColors = JSON.parse(text); 
                for (let key in newColors) {
                    if (key in root && typeof root[key] !== "function") {
                        let newColorValue = Qt.color(newColors[key]);
                        if (root[key] !== newColorValue) {
                            root[key] = newColorValue;
                        }
                    }
                }
            } catch (e) {
                // matugen 输出不完整或 JSON 异常时，保留当前配色，不炸壳。
            }
        }
        
        onFileChanged: colorFile.reload()
    }
}
