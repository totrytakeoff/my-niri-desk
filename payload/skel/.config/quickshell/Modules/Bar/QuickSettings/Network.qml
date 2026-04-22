import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.config
import qs.Widget.common

Rectangle {
    id: root
    
    property bool isHovered: mouseArea.containsMouse
    
    implicitHeight: 28
    implicitWidth: isHovered ? (layout.width + 20) : 28
    radius: height / 2 
    color: WidgetState.qsOpen && WidgetState.qsView === "network"
        ? Qt.alpha(Colorscheme.primary_container, 0.74)
        : (root.isHovered ? Colorscheme.glass_bar_hover : Colorscheme.glass_button)
    border.width: 1
    border.color: WidgetState.qsOpen && WidgetState.qsView === "network"
        ? Qt.alpha(Colorscheme.primary, 0.30)
        : Colorscheme.glass_outline

    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6
        width: isHovered ? implicitWidth : iconText.implicitWidth

        Text {
            id: iconText
            font.family: "JetBrains Mono Nerd Font" 
            font.pixelSize: 14 
            Layout.alignment: Qt.AlignVCenter
            color: WidgetState.qsOpen && WidgetState.qsView === "network"
                ? Colorscheme.on_primary_container
                : Colorscheme.on_surface
            text: {
                if (Network.activeConnectionType === "ETHERNET") return "󰈀";
                if (!Network.connected) return "󰤭"; 
                let strength = Network.signalStrength; 
                if (strength >= 80) return "󰤨";
                if (strength >= 60) return "󰤥";
                if (strength >= 40) return "󰤢";
                if (strength >= 20) return "󰤟";
                return "󰤯";
            }
        }

        Text {
            id: nameText
            text: Network.activeConnection 
            font.bold: true 
            font.pixelSize: 12 
            color: WidgetState.qsOpen && WidgetState.qsView === "network"
                ? Colorscheme.on_primary_container
                : Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter
            visible: root.isHovered
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor 
        onClicked: {
            if (WidgetState.qsOpen && WidgetState.qsView === "network") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "network";
                WidgetState.qsOpen = true;
            }
        }
    }

    HoverTag {
        open: mouseArea.containsMouse
        text: "Network"
    }
}
