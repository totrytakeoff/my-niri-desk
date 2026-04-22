import QtQuick
import Quickshell
import qs.config
import qs.Widget.common

Rectangle {
    id: root
    property bool isHovered: mouseArea.containsMouse

    color: root.isHovered
        ? Colorscheme.glass_bar_hover
        : Qt.alpha(Colorscheme.secondary_container, 0.62)
    radius: height / 2
    border.width: 1
    border.color: Colorscheme.glass_outline
    implicitHeight: isHovered ? 34 : 28
    implicitWidth: isHovered ? 34 : 28

    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        onClicked: WidgetState.notifOpen = !WidgetState.notifOpen
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\uf0f3"
        font.family: "Font Awesome 7 Free Solid"
        font.pixelSize: root.isHovered ? 14 : 12
        color: Colorscheme.on_surface
        Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    HoverTag {
        open: mouseArea.containsMouse
        text: "Notifications"
    }
}
