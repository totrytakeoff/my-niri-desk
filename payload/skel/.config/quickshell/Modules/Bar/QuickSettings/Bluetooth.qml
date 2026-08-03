import QtQuick
import QtQuick.Layouts
import qs.Services as Services
import qs.Widget.common
import qs.config

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property bool active: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property string label: {
        if (!Services.Bluetooth.powered)
            return "Off";

        if (Services.Bluetooth.connectedCount > 0)
            return "Connected";

        return "Bluetooth";
    }

    implicitHeight: 28
    implicitWidth: isHovered ? layout.implicitWidth + 20 : 28
    radius: height / 2
    color: active || Services.Bluetooth.powered ? Qt.alpha(Colorscheme.tertiary_container, 0.72) : (root.isHovered ? Colorscheme.glass_bar_hover : Colorscheme.glass_button)
    border.width: 1
    border.color: active || Services.Bluetooth.powered ? Qt.alpha(Colorscheme.tertiary, 0.3) : Colorscheme.glass_outline

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: ""
            font.family: "Font Awesome 7 Free Solid"
            font.pixelSize: 13
            color: active || Services.Bluetooth.powered ? Colorscheme.on_tertiary_container : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.label
            visible: root.isHovered
            opacity: root.isHovered ? 1 : 0
            font.bold: true
            font.pixelSize: 12
            color: active || Services.Bluetooth.powered ? Colorscheme.on_tertiary_container : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }

            }

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

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 220
        }

    }

}
