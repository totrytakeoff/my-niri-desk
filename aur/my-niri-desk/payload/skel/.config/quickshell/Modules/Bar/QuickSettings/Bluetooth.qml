import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Modules.DynamicIsland.OverviewContent
import qs.Widget.common

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property bool active: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property string label: {
        if (!ControlBackend.bluetoothEnabled) return "Off";
        if (ControlBackend.bluetoothConnected) return "Connected";
        return "Bluetooth";
    }

    implicitHeight: 28
    implicitWidth: isHovered ? layout.implicitWidth + 20 : 28
    radius: height / 2
    color: active || ControlBackend.bluetoothEnabled
        ? Qt.alpha(Colorscheme.tertiary_container, 0.72)
        : (root.isHovered ? Colorscheme.glass_bar_hover : Colorscheme.glass_button)
    border.width: 1
    border.color: active || ControlBackend.bluetoothEnabled
        ? Qt.alpha(Colorscheme.tertiary, 0.30)
        : Colorscheme.glass_outline

    Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 220 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: ""
            font.family: "Font Awesome 7 Free Solid"
            font.pixelSize: 13
            color: active || ControlBackend.bluetoothEnabled
                ? Colorscheme.on_tertiary_container
                : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.label
            visible: root.isHovered
            opacity: root.isHovered ? 1 : 0
            font.bold: true
            font.pixelSize: 12
            color: active || ControlBackend.bluetoothEnabled
                ? Colorscheme.on_tertiary_container
                : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (WidgetState.qsOpen && WidgetState.qsView === "bluetooth") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "bluetooth";
                WidgetState.qsOpen = true;
            }
        }
    }

    HoverTag {
        open: mouseArea.containsMouse
        text: "Bluetooth"
    }
}
