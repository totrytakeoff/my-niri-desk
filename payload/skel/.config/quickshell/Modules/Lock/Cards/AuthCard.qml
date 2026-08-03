import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

FocusScope {
    id: root
    property var context: null
    readonly property bool busy: context ? context.unlockInProgress : false
    readonly property bool failed: context ? context.showFailure : false
    
    signal requestUnlock()
    
    Layout.fillWidth: true
    Layout.preferredHeight: 76

    Component.onCompleted: input.forceActiveFocus()
    onActiveFocusChanged: if (activeFocus) input.forceActiveFocus()

    Rectangle {
        id: inputFrame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: Colorscheme.surface_container_highest 
        radius: 25 
        border.width: 1
        border.color: input.activeFocus ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.5) : "transparent"
        
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: parent; property: "x"; from: 0; to: 10; duration: 50 }
            NumberAnimation { target: parent; property: "x"; to: -10; duration: 50 }
            NumberAnimation { target: parent; property: "x"; to: 0; duration: 50 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 10
            spacing: 10

            // 1. 左侧锁图标
            Text {
                text: ""
                color: Colorscheme.on_surface_variant
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter 
            }

            // 2. 核心输入区
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true 

                // 幽灵输入框
                TextInput {
                    id: input
                    anchors.fill: parent
                    color: "transparent" 
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    focus: true
                    echoMode: TextInput.Password
                    enabled: !root.busy
                    
                    onAccepted: {
                        if (!root.busy && text.length > 0) root.requestUnlock()
                    }
                    
                    onTextChanged: {
                        if(root.context) root.context.currentText = text
                        if(root.context && root.context.showFailure && text.length > 0) {
                            root.context.showFailure = false
                            root.context.authState = "idle"
                        }
                        
                        // 【核心修复】：精准同步密码点模型，不牵连旧数据，彻底解决闪烁
                        var len = text.length
                        while (dotsModel.count < len) {
                            dotsModel.append({})
                        }
                        while (dotsModel.count > len) {
                            dotsModel.remove(dotsModel.count - 1)
                        }
                    }
                    
                    Connections {
                        target: root.context ? root.context : null
                        ignoreUnknownSignals: true
                        function onCurrentTextChanged() {
                            if (root.context && input.text !== root.context.currentText) {
                                input.text = root.context.currentText
                            }
                        }
                        function onShowFailureChanged() {
                            if (root.context && root.context.showFailure) {
                                shakeAnim.restart()
                                input.forceActiveFocus()
                            }
                        }
                    }
                }

                // 数据模型
                ListModel {
                    id: dotsModel
                }

                // 居中的自定义密码点：改用 ListView 以支持完美退场动画
                ListView {
                    id: dotsList
                    
                    property int dotSize: 10
                    property int dotSpacing: 8 // 【样式修改】：调小间距，让密码看起来更紧凑
                    
                    // 动态计算总宽度，驱动外层阻尼挤压感
                    width: count === 0 ? 0 : (count * dotSize) + ((count - 1) * dotSpacing)
                    height: dotSize
                    
                    // 保持绝对居中
                    x: parent ? (parent.width - width) / 2 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    
                    orientation: ListView.Horizontal
                    spacing: dotSpacing
                    interactive: false // 禁止滚动干扰

                    model: dotsModel

                    // 挤压与回弹的物理阻尼
                    Behavior on x {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    delegate: Rectangle {
                        width: dotsList.dotSize
                        height: dotsList.dotSize
                        radius: dotsList.dotSize / 2
                        color: Colorscheme.on_surface
                    }

                    // 进场动画：新圆球弹出淡入
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                            NumberAnimation { property: "scale"; from: 0.3; to: 1; duration: 250; easing.type: Easing.OutBack }
                        }
                    }

                    // 退场动画：旧圆球删除时的平滑缩小淡出
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                            NumberAnimation { property: "scale"; to: 0.3; duration: 150; easing.type: Easing.InBack }
                        }
                    }
                }
            }
            
            // 3. 提交按钮
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 32; height: 32; radius: 16
                
                property bool hasText: input.text.length > 0 && !root.busy
                
                color: hasText ? Colorscheme.primary : "transparent"
                border.width: hasText ? 0 : 1
                border.color: hasText ? "transparent" : Colorscheme.outline
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Text { 
                    anchors.centerIn: parent
                    text: root.busy ? "…" : "➜"
                    color: parent.hasText ? Colorscheme.on_primary : Colorscheme.outline
                    font.pixelSize: 14
                    font.bold: true
                }
                
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: parent.hasText
                    onClicked: {
                        input.forceActiveFocus()
                        if(parent.hasText) root.requestUnlock()
                    }
                }
            }
        }
    }

    Text {
        anchors.top: inputFrame.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.busy ? "正在验证…" : "密码错误，请重试"
        color: root.busy ? Colorscheme.primary : Colorscheme.error
        font.family: Sizes.fontFamily
        font.pixelSize: 12
        font.bold: true
        visible: root.busy || root.failed
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: (mouse) => {
            input.forceActiveFocus()
            mouse.accepted = false
        }
    }
}
