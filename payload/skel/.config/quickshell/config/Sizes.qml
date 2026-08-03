pragma Singleton
import Quickshell

Singleton {
    // 全局尺寸 / 字体常量
    // -----------------------------------------------------------------------
    // 这份文件专门放“不随页面变化的常量”：
    // - 字体族
    // - 通用圆角
    // - bar 高度
    // - 锁屏卡片尺寸
    //
    // 适合放“整个桌面都应保持一致”的数值。
    readonly property string fontFamily: "LXGW WenKai GB Screen"
    // 代码 / 等宽场景建议都走这个。
    readonly property string fontFamilyMono: "JetBrains Mono Nerd Font"
    readonly property string fontIcon: "LXGW WenKai GB Screen"
    readonly property real cornerRadius: 10
    // Bar 窗口负责给平铺布局预留 52px；内部胶囊统一为 36px。
    readonly property real barWindowHeight: 52
    readonly property real barPillHeight: 36
    // 兼容旧组件；新代码应使用语义更明确的 barPillHeight。
    readonly property real barHeight: barPillHeight
    // 顶栏系统指标收起时默认显示哪一项。
    // 可选值: "ram" | "cpu" | "temp" | "disk"
    readonly property string collapsedSysMetric: "ram"

    // 锁屏专用尺寸。
    readonly property real lockCardRadius: 24
    readonly property real lockCardPadding: 20
    readonly property real lockIconSize: 24
}
