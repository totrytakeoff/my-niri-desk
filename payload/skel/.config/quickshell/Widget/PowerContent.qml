import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import qs.Services as Services
import qs.Widget.common
import qs.config

Item {
    id: root

    property string pendingAction: ""
    property string pendingLabel: ""
    property bool pendingDanger: false
    property string activePolicyId: ""
    property string activePolicyTitle: ""
    property var activePolicyValues: []
    property real activePolicyValue: 0
    property string activePolicyZeroLabel: "永不"
    property string recentlyClosedPolicyId: ""

    function compactDurationLabel(value, zeroLabel) {
        const numeric = Number(value);
        if (numeric < 0)
            return "永不";

        if (numeric === 0)
            return zeroLabel || "永不";

        if (numeric < 1)
            return `${Math.round(numeric * 60)}s`;

        if (numeric >= 60 && numeric % 60 === 0)
            return `${numeric / 60}h`;

        return `${numeric}m`;
    }

    function openPolicyMenu(policyId, title, values, currentValue, zeroLabel, anchorItem) {
        if (!policyPopup.opened && root.recentlyClosedPolicyId === policyId) {
            root.recentlyClosedPolicyId = "";
            policyCloseGuardTimer.stop();
            return ;
        }
        if (policyPopup.opened && root.activePolicyId === policyId) {
            policyPopup.close();
            return ;
        }
        root.recentlyClosedPolicyId = "";
        policyCloseGuardTimer.stop();
        root.activePolicyId = policyId;
        root.activePolicyTitle = title;
        root.activePolicyValues = values;
        root.activePolicyValue = currentValue;
        root.activePolicyZeroLabel = zeroLabel || "永不";
        const popupParent = policyPopup.parent;
        const anchorPosition = anchorItem.mapToItem(popupParent, 0, 0);
        const centeredX = anchorPosition.x + anchorItem.width / 2 - policyPopup.width / 2;
        policyPopup.x = Math.max(8, Math.min(popupParent.width - policyPopup.width - 8, centeredX));
        policyPopup.y = anchorPosition.y + anchorItem.height + 7;
        policyPopup.open();
    }

    function selectPolicyValue(value) {
        switch (root.activePolicyId) {
        case "screen":
            Services.Power.setScreenTimeout(value);
            break;
        case "lock-delay":
            Services.Power.setAutoLockDelay(value);
            break;
        case "lock-screen":
            Services.Power.setLockScreenTimeout(value);
            break;
        case "suspend":
            Services.Power.setSuspendTimeout(value);
            break;
        }
        policyPopup.close();
    }

    function closeAndRun(action) {
        WidgetState.qsOpen = false;
        Qt.callLater(() => {
            Services.Power.runSessionAction(action);
        });
    }

    function runImmediate(action) {
        if (action === "lock") {
            WidgetState.qsOpen = false;
            Qt.callLater(() => {
                WidgetState.requestLock("manual");
            });
            return ;
        }
        closeAndRun(action);
    }

    function requestConfirmation(action, label, danger) {
        root.pendingAction = action;
        root.pendingLabel = label;
        root.pendingDanger = danger;
        confirmationTimer.restart();
    }

    function cancelConfirmation() {
        root.pendingAction = "";
        root.pendingLabel = "";
        confirmationTimer.stop();
    }

    function confirmPendingAction() {
        const action = root.pendingAction;
        root.cancelConfirmation();
        root.closeAndRun(action);
    }

    onVisibleChanged: {
        if (visible) {
            Services.Power.refreshManagementState();
        } else {
            root.cancelConfirmation();
            policyPopup.close();
        }
    }

    Theme {
        id: theme
    }

    Timer {
        id: confirmationTimer

        interval: 8000
        repeat: false
        onTriggered: root.cancelConfirmation()
    }

    Timer {
        id: policyCloseGuardTimer

        interval: 800
        repeat: false
        onTriggered: root.recentlyClosedPolicyId = ""
    }

    Connections {
        function onQsOpenChanged() {
            if (!WidgetState.qsOpen)
                policyPopup.close();

        }

        target: WidgetState
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            radius: 22
            color: theme.glass_card_subtle
            border.width: 1
            border.color: theme.glass_outline_soft

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76
                    Layout.alignment: Qt.AlignVCenter
                    radius: 24
                    color: Qt.alpha(Services.Power.criticalBattery ? Colorscheme.error_container : Colorscheme.primary_container, 0.68)
                    border.width: 1
                    border.color: Qt.alpha(Services.Power.criticalBattery ? Colorscheme.error : Colorscheme.primary, 0.28)

                    Text {
                        anchors.centerIn: parent
                        text: Services.Power.batteryIcon
                        font.family: "Font Awesome 7 Free Solid"
                        font.pixelSize: 30
                        color: Services.Power.criticalBattery ? Colorscheme.on_error_container : Colorscheme.on_primary_container
                    }

                    Rectangle {
                        visible: Services.Power.stateBadgeIcon !== ""
                        width: 25
                        height: 25
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        color: Colorscheme.primary
                        border.width: 2
                        border.color: Qt.alpha(Colorscheme.background, 0.74)

                        Text {
                            anchors.centerIn: parent
                            text: Services.Power.stateBadgeIcon
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: 10
                            color: Colorscheme.on_primary
                        }

                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: Services.Power.batteryAvailable ? `${Services.Power.batteryPercent}%` : "电源中心"
                            color: theme.text
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: Services.Power.batteryAvailable ? 30 : 24
                            font.bold: true
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: profileLabel.implicitWidth + 16
                            implicitHeight: 24
                            radius: height / 2
                            color: Qt.alpha(Colorscheme.secondary_container, 0.62)
                            border.width: 1
                            border.color: theme.glass_outline_soft

                            Text {
                                id: profileLabel

                                anchors.centerIn: parent
                                text: `${Services.Power.profileName}模式`
                                color: Colorscheme.on_secondary_container
                                font.pixelSize: 10
                                font.bold: true
                            }

                        }

                        Item {
                            Layout.fillWidth: true
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: Services.Power.stateText
                        color: theme.subtext
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7
                        radius: height / 2
                        color: Qt.alpha(Colorscheme.on_surface_variant, 0.16)
                        visible: Services.Power.batteryAvailable

                        Rectangle {
                            width: parent.width * Services.Power.batteryLevel
                            height: parent.height
                            radius: height / 2
                            color: Services.Power.criticalBattery ? Colorscheme.error : Colorscheme.primary

                            Behavior on width {
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            visible: Services.Power.healthAvailable
                            text: `健康度 ${Services.Power.healthPercent}%`
                            color: theme.subtext
                            font.pixelSize: 10
                        }

                        Text {
                            visible: Services.Power.timeText !== ""
                            text: Services.Power.timeText
                            color: theme.subtext
                            font.pixelSize: 10
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: Services.Power.statusText !== ""
                            text: Services.Power.statusText
                            color: Services.Power.statusError ? Colorscheme.error : Colorscheme.primary
                            font.pixelSize: 10
                            font.bold: true
                        }

                    }

                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: 20
            color: theme.glass_card_subtle
            border.width: 1
            border.color: theme.glass_outline_soft

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: policyRow

                    Layout.fillWidth: true

                    Text {
                        text: "电源模式"
                        color: theme.text
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: Services.Power.profileKey === "performance" && !Services.Power.hasPerformanceProfile
                        text: "性能模式不可用"
                        color: Colorscheme.error
                        font.pixelSize: 10
                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    ProfileButton {
                        profileKey: "power-saver"
                        icon: "\uf06c"
                        label: "节能"
                    }

                    ProfileButton {
                        profileKey: "balanced"
                        icon: "\uf24e"
                        label: "平衡"
                    }

                    ProfileButton {
                        profileKey: "performance"
                        icon: "\uf135"
                        label: "性能"
                        controlEnabled: Services.Power.hasPerformanceProfile
                    }

                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: 20
            color: theme.glass_card_subtle
            border.width: 1
            border.color: theme.glass_outline_soft

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                SettingToggle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "\uf1e6"
                    title: "插电 / 电池自动切换"
                    description: Services.Power.batteryAwareSupported ? "根据供电状态自动调整性能策略" : "当前 Power Profiles 不支持"
                    checked: Services.Power.batteryAwareEnabled
                    busy: Services.Power.batteryAwareBusy
                    controlEnabled: Services.Power.batteryAwareSupported
                    onToggled: (checked) => {
                        return Services.Power.setBatteryAware(checked);
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: theme.glass_outline_soft
                }

                SettingToggle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "\uf3ed"
                    title: "电池充电保护"
                    description: Services.Power.chargeLimitDescription
                    checked: Services.Power.chargeLimitEnabled
                    busy: Services.Power.chargeLimitBusy
                    controlEnabled: Services.Power.chargeLimitSupported
                    onToggled: (checked) => {
                        return Services.Power.setChargeLimit(checked);
                    }
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 116
            radius: 20
            color: theme.glass_card_subtle
            border.width: 1
            border.color: theme.glass_outline_soft

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                SettingToggle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    icon: "\uf0f4"
                    title: "Caffeine 模式"
                    description: Services.Power.caffeineEnabled ? "保持常亮，自动熄屏与睡眠已暂停" : Services.Power.idlePolicySummary
                    checked: Services.Power.caffeineEnabled
                    onToggled: (checked) => {
                        Services.Power.setCaffeine(checked);
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: theme.glass_outline_soft
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    PolicySummaryTile {
                        policyId: "screen"
                        title: "熄屏"
                        popupTitle: "熄屏时间"
                        values: [0, 1, 5, 10, 15, 30]
                        currentValue: Services.Power.screenTimeoutMinutes
                    }

                    PolicySummaryTile {
                        policyId: "lock-delay"
                        title: "后锁定"
                        popupTitle: "熄屏后锁定"
                        values: [-1, 0, 1, 5, 10]
                        zeroLabel: "立即"
                        currentValue: Services.Power.autoLockDelayMinutes
                        controlEnabled: Services.Power.screenTimeoutMinutes > 0
                    }

                    PolicySummaryTile {
                        policyId: "lock-screen"
                        title: "锁屏熄屏"
                        popupTitle: "锁屏熄屏"
                        values: [0, 0.25, 0.5, 1, 2]
                        currentValue: Services.Power.lockScreenTimeoutMinutes
                    }

                    PolicySummaryTile {
                        policyId: "suspend"
                        title: "睡眠"
                        popupTitle: "自动睡眠"
                        values: [0, 15, 30, 60, 120]
                        currentValue: Services.Power.suspendTimeoutMinutes
                    }

                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 142
            radius: 20
            color: theme.glass_card_subtle
            border.width: 1
            border.color: theme.glass_outline_soft

            Text {
                id: actionTitle

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.topMargin: 10
                text: root.pendingAction === "" ? "会话与电源" : "确认操作"
                color: theme.text
                font.pixelSize: 13
                font.bold: true
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: actionTitle.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 10

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 7
                    visible: root.pendingAction === ""

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 7

                        ActionButton {
                            icon: "\uf023"
                            label: "锁定"
                            onClicked: root.runImmediate("lock")
                        }

                        ActionButton {
                            icon: "\uf186"
                            label: "睡眠"
                            controlEnabled: Services.Power.canSuspend
                            onClicked: root.runImmediate("suspend")
                        }

                        ActionButton {
                            icon: "\uf2f5"
                            label: "注销"
                            onClicked: root.requestConfirmation("logout", "退出当前 Niri 会话？", false)
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 7

                        ActionButton {
                            visible: Services.Power.canHibernate
                            icon: "\uf2dc"
                            label: "休眠"
                            onClicked: root.runImmediate("hibernate")
                        }

                        ActionButton {
                            icon: "\uf2f1"
                            label: "重新启动"
                            danger: true
                            onClicked: root.requestConfirmation("reboot", "确定要重新启动吗？", true)
                        }

                        ActionButton {
                            icon: "\uf011"
                            label: "关机"
                            danger: true
                            onClicked: root.requestConfirmation("poweroff", "确定要关闭电脑吗？", true)
                        }

                    }

                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: root.pendingAction !== ""

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: Qt.alpha(root.pendingDanger ? Colorscheme.error_container : Colorscheme.primary_container, 0.72)

                        Text {
                            anchors.centerIn: parent
                            text: root.pendingDanger ? "\uf071" : "\uf2f5"
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: 15
                            color: root.pendingDanger ? Colorscheme.on_error_container : Colorscheme.on_primary_container
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.pendingLabel
                            color: theme.text
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "该操作需要再次确认"
                            color: theme.subtext
                            font.pixelSize: 10
                        }

                    }

                    ConfirmButton {
                        label: "取消"
                        onClicked: root.cancelConfirmation()
                    }

                    ConfirmButton {
                        label: "确认"
                        danger: root.pendingDanger
                        emphasized: true
                        onClicked: root.confirmPendingAction()
                    }

                }

            }

        }

    }

    QQC2.Popup {
        id: policyPopup

        parent: policyRow
        width: Math.min(318, root.width - 16)
        height: 82
        padding: 0
        modal: false
        dim: false
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        onAboutToHide: {
            root.recentlyClosedPolicyId = root.activePolicyId;
            policyCloseGuardTimer.restart();
        }
        onClosed: {
            if (!policyPopup.opened)
                root.activePolicyId = "";

        }

        background: Rectangle {
            radius: 18
            color: Colorscheme.glass_popup
            border.width: 1
            border.color: Qt.alpha(Colorscheme.primary, 0.22)
        }

        contentItem: ColumnLayout {
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 8

                Text {
                    text: root.activePolicyTitle
                    color: theme.text
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.compactDurationLabel(root.activePolicyValue, root.activePolicyZeroLabel)
                    color: Colorscheme.primary
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                spacing: 5

                Repeater {
                    model: root.activePolicyValues

                    DurationChip {
                        value: Number(modelData)
                        currentValue: root.activePolicyValue
                        label: root.compactDurationLabel(modelData, root.activePolicyZeroLabel)
                        onClicked: (value) => {
                            root.selectPolicyValue(value);
                        }
                    }

                }

            }

        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.35
                }

            }

        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 100
            }

        }

    }

    component ProfileButton: Rectangle {
        id: profileButton

        property string profileKey: "balanced"
        property string icon: ""
        property string label: ""
        property bool controlEnabled: true
        property bool active: Services.Power.profileKey === profileKey

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 15
        color: active ? Qt.alpha(Colorscheme.primary_container, 0.82) : (profileMouse.containsMouse && controlEnabled ? theme.glass_card_hover : "transparent")
        border.width: active || profileMouse.containsMouse ? 1 : 0
        border.color: active ? Qt.alpha(Colorscheme.primary, 0.34) : theme.glass_outline_soft
        opacity: controlEnabled ? 1 : 0.42

        RowLayout {
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: profileButton.icon
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 12
                color: profileButton.active ? Colorscheme.on_primary_container : theme.text
            }

            Text {
                text: profileButton.label
                color: profileButton.active ? Colorscheme.on_primary_container : theme.text
                font.pixelSize: 11
                font.bold: true
            }

        }

        MouseArea {
            id: profileMouse

            anchors.fill: parent
            enabled: profileButton.controlEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Services.Power.setProfile(profileButton.profileKey)
        }

        Behavior on color {
            ColorAnimation {
                duration: 180
            }

        }

    }

    component SettingToggle: Item {
        id: setting

        property string icon: ""
        property string title: ""
        property string description: ""
        property bool checked: false
        property bool busy: false
        property bool controlEnabled: true

        signal toggled(bool checked)

        opacity: controlEnabled ? 1 : 0.48

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: settingMouse.containsMouse && setting.controlEnabled ? theme.glass_card_hover : "transparent"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Text {
                text: setting.icon
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 13
                color: setting.checked ? Colorscheme.primary : theme.subtext
                Layout.preferredWidth: 18
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: setting.title
                    color: theme.text
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: setting.description
                    color: theme.subtext
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

            }

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: setting.checked ? Colorscheme.primary : Qt.alpha(Colorscheme.on_surface_variant, 0.22)
                border.width: setting.checked ? 0 : 1
                border.color: theme.glass_outline_soft

                Rectangle {
                    width: 16
                    height: 16
                    radius: width / 2
                    y: 3
                    x: setting.checked ? parent.width - width - 3 : 3
                    color: setting.checked ? Colorscheme.on_primary : theme.subtext

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    visible: setting.busy
                    text: "…"
                    color: setting.checked ? Colorscheme.on_primary : theme.text
                    font.bold: true
                }

            }

        }

        MouseArea {
            id: settingMouse

            anchors.fill: parent
            enabled: setting.controlEnabled && !setting.busy
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: setting.toggled(!setting.checked)
        }

    }

    component ActionButton: Rectangle {
        id: actionButton

        property string icon: ""
        property string label: ""
        property bool danger: false
        property bool controlEnabled: true

        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 14
        color: {
            if (actionMouse.containsMouse && actionButton.controlEnabled)
                return actionButton.danger ? Qt.alpha(Colorscheme.error_container, 0.52) : theme.glass_card_hover;

            return actionButton.danger ? Qt.alpha(Colorscheme.error_container, 0.12) : "transparent";
        }
        border.width: actionMouse.containsMouse && actionButton.controlEnabled ? 1 : 0
        border.color: actionButton.danger ? Qt.alpha(Colorscheme.error, 0.3) : theme.glass_outline_soft
        opacity: controlEnabled ? 1 : 0.4

        RowLayout {
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: actionButton.icon
                font.family: "Font Awesome 7 Free Solid"
                font.pixelSize: 12
                color: actionButton.danger ? Colorscheme.error : theme.text
            }

            Text {
                text: actionButton.label
                color: actionButton.danger ? Colorscheme.on_error_container : theme.text
                font.pixelSize: 10
                font.bold: true
            }

        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            enabled: actionButton.controlEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: actionButton.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: 160
            }

        }

    }

    component PolicySummaryTile: Rectangle {
        id: policyTile

        property string policyId: ""
        property string title: ""
        property string popupTitle: ""
        property var values: []
        property real currentValue: 0
        property string zeroLabel: "永不"
        property bool controlEnabled: true
        readonly property bool menuActive: policyPopup.opened && root.activePolicyId === policyId

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 13
        opacity: controlEnabled ? 1 : 0.38
        color: menuActive ? Qt.alpha(Colorscheme.primary_container, 0.68) : (policyMouse.containsMouse && controlEnabled ? theme.glass_card_hover : "transparent")
        border.width: menuActive || (policyMouse.containsMouse && controlEnabled) ? 1 : 0
        border.color: menuActive ? Qt.alpha(Colorscheme.primary, 0.32) : theme.glass_outline_soft

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: policyTile.title
                color: policyTile.menuActive ? Colorscheme.on_primary_container : theme.subtext
                font.pixelSize: 9
                font.bold: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Text {
                    text: root.compactDurationLabel(policyTile.currentValue, policyTile.zeroLabel)
                    color: policyTile.menuActive ? Colorscheme.on_primary_container : theme.text
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    text: "\uf107"
                    color: policyTile.menuActive ? Colorscheme.on_primary_container : theme.subtext
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 8
                    rotation: policyTile.menuActive ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 160
                        }

                    }

                }

            }

        }

        MouseArea {
            id: policyMouse

            anchors.fill: parent
            enabled: policyTile.controlEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.openPolicyMenu(policyTile.policyId, policyTile.popupTitle, policyTile.values, policyTile.currentValue, policyTile.zeroLabel, policyTile)
        }

        Behavior on color {
            ColorAnimation {
                duration: 160
            }

        }

    }

    component DurationChip: Rectangle {
        id: durationChip

        property real value: 0
        property real currentValue: 0
        property string label: ""
        property bool active: Math.abs(value - currentValue) < 0.001
        property bool controlEnabled: true

        signal clicked(real value)

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        radius: height / 2
        color: active ? Qt.alpha(Colorscheme.primary_container, 0.78) : (durationMouse.containsMouse ? theme.glass_card_hover : "transparent")
        border.width: active || durationMouse.containsMouse ? 1 : 0
        border.color: active ? Qt.alpha(Colorscheme.primary, 0.3) : theme.glass_outline_soft

        Text {
            anchors.centerIn: parent
            text: durationChip.label
            color: durationChip.active ? Colorscheme.on_primary_container : theme.subtext
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 9
            font.bold: durationChip.active
        }

        MouseArea {
            id: durationMouse

            anchors.fill: parent
            enabled: durationChip.controlEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: durationChip.clicked(durationChip.value)
        }

        Behavior on color {
            ColorAnimation {
                duration: 160
            }

        }

    }

    component ConfirmButton: Rectangle {
        id: confirmButton

        property string label: ""
        property bool danger: false
        property bool emphasized: false

        signal clicked()

        Layout.preferredWidth: 58
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        radius: height / 2
        color: {
            if (emphasized)
                return danger ? Colorscheme.error : Colorscheme.primary;

            return confirmMouse.containsMouse ? theme.glass_card_hover : "transparent";
        }
        border.width: emphasized ? 0 : 1
        border.color: theme.glass_outline_soft

        Text {
            anchors.centerIn: parent
            text: confirmButton.label
            color: confirmButton.emphasized ? (confirmButton.danger ? Colorscheme.on_error : Colorscheme.on_primary) : theme.text
            font.pixelSize: 10
            font.bold: true
        }

        MouseArea {
            id: confirmMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: confirmButton.clicked()
        }

    }

}
