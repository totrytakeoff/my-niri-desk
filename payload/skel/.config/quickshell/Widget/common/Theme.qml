import QtQuick
import qs.config

QtObject {
    property color background: Colorscheme.background
    property color surface: Colorscheme.surface_container
    property color primary: Colorscheme.primary
    property color primary_container: Colorscheme.primary_container
    property color on_primary: Colorscheme.on_primary
    property color on_primary_container: Colorscheme.on_primary_container
    property color error: Colorscheme.error
    property color text: Colorscheme.on_surface
    property color on_surface: Colorscheme.on_surface
    property color subtext: Colorscheme.on_surface_variant
    property color outline: Colorscheme.outline
    property color secondary: Colorscheme.secondary
    property color surface_variant: Colorscheme.surface_variant
    property color surface_container_highest: Colorscheme.surface_container_highest
    property color glass_panel: Colorscheme.glass_panel
    property color glass_popup: Colorscheme.glass_popup
    property color glass_card_subtle: Colorscheme.glass_card_subtle
    property color glass_card_hover: Colorscheme.glass_card_hover
    property color glass_outline_soft: Colorscheme.glass_outline_soft
    // 【修改】：精致的圆角和内边距，适应 420 宽度
    property int radius: 24
    property int padding: 20
}
