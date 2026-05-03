import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clipboard-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    function requestClose() {
        if (!root.visible) return
        root.visible = false
    }

    function toggleWindow() {
        if (root.visible) requestClose()
        else root.visible = true
    }

    onVisibleChanged: {
        if (visible) {
            clipboardPage.refresh()
            clipboardPage.forceSearchFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    Rectangle {
        id: mainUI
        width: Math.min(860, root.width - 80)
        height: Math.min(560, root.height - 120)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: 20
        color: "transparent"
        focus: true

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: mask
            anchors.fill: parent
            radius: parent.radius
            visible: false
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: mask }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.06, 0.06, 0.1, 0.88)
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Colorscheme.inverse_surface.r, Colorscheme.inverse_surface.g, Colorscheme.inverse_surface.b, 0.08)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 14
                        color: Qt.alpha(Colorscheme.primary_container, 0.76)

                        Text {
                            anchors.centerIn: parent
                            text: "content_paste"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                            color: Colorscheme.on_primary_container
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Clipboard"
                            color: Colorscheme.on_surface
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            text: "cliphist history"
                            color: Colorscheme.on_surface_variant
                            font.pixelSize: 12
                            font.family: "JetBrains Mono Nerd Font"
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 12
                        color: closeMouse.containsMouse ? Colorscheme.surface_variant : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 21
                            color: Colorscheme.on_surface_variant
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestClose()
                        }
                    }
                }

                ClipboardPage {
                    id: clipboardPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onRequestClose: root.requestClose()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Colorscheme.glass_outline
            border.width: 1
            radius: parent.radius
        }
    }
}
