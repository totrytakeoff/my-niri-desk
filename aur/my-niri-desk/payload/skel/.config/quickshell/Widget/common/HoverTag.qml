import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config

PopupWindow {
    id: root

    property bool open: false
    property string text: ""
    property int delay: 550
    property int offset: 8
    property bool armed: false

    color: "transparent"
    visible: armed && open && text !== ""

    implicitWidth: tagText.implicitWidth + 22
    implicitHeight: tagText.implicitHeight + 14

    anchor.item: parent
    anchor.rect.x: Math.round((anchor.item.width - implicitWidth) / 2)
    anchor.rect.y: anchor.item.height + root.offset
    anchor.rect.width: implicitWidth
    anchor.rect.height: implicitHeight

    onOpenChanged: {
        if (open && text !== "") {
            showTimer.restart();
        } else {
            showTimer.stop();
            armed = false;
        }
    }

    onTextChanged: {
        if (text === "") {
            showTimer.stop();
            armed = false;
        }
    }

    Timer {
        id: showTimer
        interval: root.delay
        repeat: false
        onTriggered: root.armed = true
    }

    Rectangle {
        id: tagBg
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(
            Colorscheme.surface_container_high.red,
            Colorscheme.surface_container_high.green,
            Colorscheme.surface_container_high.blue,
            0.96
        )
        border.width: 1
        border.color: Qt.rgba(
            Colorscheme.outline_variant.red,
            Colorscheme.outline_variant.green,
            Colorscheme.outline_variant.blue,
            0.7
        )
    }

    MultiEffect {
        source: tagBg
        anchors.fill: tagBg
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.35)
        shadowBlur: 0.8
        shadowVerticalOffset: 4
    }

    Text {
        id: tagText
        anchors.centerIn: parent
        text: root.text
        color: Colorscheme.on_surface
        font.family: Sizes.fontFamily
        font.pixelSize: 12
        font.bold: true
    }
}
