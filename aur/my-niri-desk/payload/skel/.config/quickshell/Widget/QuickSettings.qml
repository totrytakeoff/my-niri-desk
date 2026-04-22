import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Widget.common

Item {
    id: root

    // 右侧快捷设置总容器
    // -----------------------------------------------------------------------
    // 这里只负责“顶部视图切换 + 三页切换动画”。
    // 具体逻辑分别下沉到：
    // - NetworkContent
    // - BluetoothContent
    // - AudioContent
    //
    // 所以如果你只是想改：
    // - 顶部 chip 文案
    // - 当前默认页
    // - 切换动画
    // 优先看这个文件。

    Theme { id: theme }

    component ViewChip : Rectangle {
        id: chip
        property string viewId: ""
        property string icon: ""
        property string label: ""
        // 当前 chip 是否是激活页。
        property bool active: WidgetState.qsView === viewId

        radius: height / 2
        color: active ? Colorscheme.primary_container : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.7)
        border.width: active ? 0 : 1
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.45)
        implicitHeight: 34
        implicitWidth: layout.implicitWidth + 22

        Behavior on color { ColorAnimation { duration: 180 } }

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: chip.icon
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 13
                color: chip.active ? Colorscheme.on_primary_container : theme.text
            }

            Text {
                text: chip.label
                font.bold: true
                font.pixelSize: 12
                color: chip.active ? Colorscheme.on_primary_container : theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                WidgetState.qsView = chip.viewId;
                WidgetState.qsOpen = true;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // 右侧快捷设置目前固定 3 页。
            ViewChip { viewId: "network"; icon: ""; label: "Network" }
            ViewChip { viewId: "bluetooth"; icon: ""; label: "Bluetooth" }
            ViewChip { viewId: "audio"; icon: ""; label: "Audio" }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NetworkContent {
                anchors.fill: parent

                opacity: WidgetState.qsView === "network" ? 1.0 : 0.0
                scale: WidgetState.qsView === "network" ? 1.0 : 0.95
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            }

            BluetoothContent {
                anchors.fill: parent

                opacity: WidgetState.qsView === "bluetooth" ? 1.0 : 0.0
                scale: WidgetState.qsView === "bluetooth" ? 1.0 : 0.95
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            }

            AudioContent {
                anchors.fill: parent

                opacity: WidgetState.qsView === "audio" ? 1.0 : 0.0
                scale: WidgetState.qsView === "audio" ? 1.0 : 0.95
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            }
        }
    }
}
