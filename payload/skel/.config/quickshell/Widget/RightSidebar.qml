import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Widget.common
import qs.config

PanelWindow {
    id: root

    property int sidebarWidth: 420
    property int gap: 24
    property int gooeyRadius: 36
    property int qsTargetHeight: WidgetState.qsView === "power" ? 800 : 640
    property int targetX: 600 - sidebarWidth - gap
    property int offScreenX: 600

    screen: Niri.focusedScreen
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-unified-sidebar"
    WlrLayershell.keyboardFocus: WidgetState.qsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: 600
    color: "transparent"

    Theme {
        id: theme
    }

    anchors {
        right: true
        top: true
        bottom: true
    }

    Item {
        id: hitBoxRegion

        x: qsShadow.x
        y: 66
        width: sidebarWidth
        height: root.qsTargetHeight
    }

    Item {
        id: renderCanvas

        width: parent.width + 100
        height: parent.height
        x: 0
        y: 0

        Item {
            id: rawShapes

            anchors.fill: parent
            visible: false

            Rectangle {
                id: qsShadow

                width: root.sidebarWidth
                height: root.qsTargetHeight
                y: 66
                x: WidgetState.qsOpen ? root.targetX : root.offScreenX
                radius: theme.radius
                color: "black"

                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.3
                    }

                }

            }

            Rectangle {
                id: offscreenWall

                width: 100
                height: parent.height
                x: root.offScreenX
                color: "black"
            }

        }

        GaussianBlur {
            id: blurredShapes

            anchors.fill: parent
            source: rawShapes
            radius: root.gooeyRadius
            samples: 1 + root.gooeyRadius * 2
            visible: false
        }

        Rectangle {
            id: solidBg

            anchors.fill: parent
            color: theme.glass_panel
            visible: false
        }

        ThresholdMask {
            id: gooeyLayer

            anchors.fill: parent
            source: solidBg
            maskSource: blurredShapes
            threshold: 0.51
            spread: 0.02
        }

    }

    Item {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            visible: WidgetState.qsOpen
            onClicked: WidgetState.qsOpen = false
        }

        Item {
            z: 1
            width: qsShadow.width
            height: qsShadow.height
            x: qsShadow.x
            y: qsShadow.y
            clip: true

            QuickSettings {
                anchors.fill: parent
            }

        }

    }

    Shortcut {
        sequence: "Escape"
        enabled: WidgetState.qsOpen
        onActivated: WidgetState.qsOpen = false
    }

    BackgroundEffect.blurRegion: Region {
        item: hitBoxRegion
        radius: theme.radius
    }

    mask: Region {
        item: hitBoxRegion
    }

}
