import QtQuick
import QtQuick.Layouts
import qs.Services as Services
import qs.Widget.common
import qs.config

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property bool active: WidgetState.qsOpen && WidgetState.qsView === "power"

    implicitHeight: 28
    implicitWidth: Services.Power.batteryAvailable ? 74 : 28
    radius: height / 2
    color: {
        if (active)
            return Qt.alpha(Colorscheme.primary_container, 0.74);

        if (Services.Power.criticalBattery)
            return Qt.alpha(Colorscheme.error_container, 0.76);

        if (Services.Power.lowBattery)
            return Qt.alpha(Colorscheme.tertiary_container, 0.72);

        return root.isHovered ? Colorscheme.glass_bar_hover : Colorscheme.glass_button;
    }
    border.width: 1
    border.color: {
        if (active)
            return Qt.alpha(Colorscheme.primary, 0.3);

        if (Services.Power.criticalBattery)
            return Qt.alpha(Colorscheme.error, 0.42);

        return Colorscheme.glass_outline;
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: Services.Power.batteryIcon
            font.family: "Font Awesome 7 Free Solid"
            font.pixelSize: 13
            color: Services.Power.criticalBattery ? Colorscheme.error : (root.active ? Colorscheme.on_primary_container : Colorscheme.on_surface)
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: Services.Power.batteryAvailable
            text: `${Services.Power.batteryPercent}%`
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 11
            font.bold: true
            color: root.active ? Colorscheme.on_primary_container : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: Services.Power.stateBadgeIcon !== ""
            text: Services.Power.stateBadgeIcon
            font.family: "Font Awesome 7 Free Solid"
            font.pixelSize: 7
            color: Services.Power.criticalBattery ? Colorscheme.error : (root.active ? Colorscheme.on_primary_container : Colorscheme.primary)
            Layout.alignment: Qt.AlignTop
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: WidgetState.toggleQuickSettings("power")
    }

    HoverTag {
        open: mouseArea.containsMouse
        text: Services.Power.batteryAvailable ? `${Services.Power.stateText} · ${Services.Power.profileName}模式` : "电源中心"
    }

    Behavior on color {
        ColorAnimation {
            duration: 180
        }

    }

}
