import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.config
pragma Singleton

Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery !== null && battery.ready && battery.isPresent
    readonly property real batteryLevel: {
        if (!batteryAvailable)
            return 0;

        const value = Number(battery.percentage);
        return Math.max(0, Math.min(1, value > 1 ? value / 100 : value));
    }
    readonly property int batteryPercent: Math.round(batteryLevel * 100)
    readonly property real healthLevel: {
        if (!batteryAvailable || !battery.healthSupported)
            return 0;

        const value = Number(battery.healthPercentage);
        return Math.max(0, Math.min(1, value > 1 ? value / 100 : value));
    }
    readonly property int healthPercent: Math.round(healthLevel * 100)
    readonly property bool healthAvailable: batteryAvailable && battery.healthSupported
    readonly property bool onBattery: batteryAvailable && UPower.onBattery
    readonly property bool pluggedIn: batteryAvailable && !UPower.onBattery
    readonly property bool charging: batteryAvailable && battery.state === UPowerDeviceState.Charging
    readonly property bool discharging: batteryAvailable && battery.state === UPowerDeviceState.Discharging
    readonly property bool fullyCharged: batteryAvailable && battery.state === UPowerDeviceState.FullyCharged
    readonly property bool pendingCharge: batteryAvailable && battery.state === UPowerDeviceState.PendingCharge
    readonly property bool lowBattery: onBattery && batteryPercent <= 20
    readonly property bool criticalBattery: onBattery && batteryPercent <= 10
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property string profileKey: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }
    readonly property string profileName: {
        switch (profileKey) {
        case "power-saver":
            return "节能";
        case "performance":
            return "性能";
        default:
            return "平衡";
        }
    }
    readonly property string batteryIcon: {
        if (!batteryAvailable)
            return "\uf011";

        if (batteryLevel >= 0.9)
            return "\uf240";

        if (batteryLevel >= 0.65)
            return "\uf241";

        if (batteryLevel >= 0.4)
            return "\uf242";

        if (batteryLevel >= 0.15)
            return "\uf243";

        return "\uf244";
    }
    readonly property string stateBadgeIcon: {
        if (charging)
            return "\uf0e7";

        if (pluggedIn && chargeLimitEnabled)
            return "\uf06c";

        if (pluggedIn)
            return "\uf1e6";

        return "";
    }
    readonly property string stateText: {
        if (!batteryAvailable)
            return "未检测到电池";

        if (charging)
            return "正在充电";

        if (fullyCharged)
            return "已充满 · 接入电源";

        if (pendingCharge && chargeLimitEnabled)
            return "已接入电源 · 充电保护中";

        if (pendingCharge)
            return "已接入电源 · 等待充电";

        if (pluggedIn)
            return "已接入电源";

        return "正在使用电池";
    }
    readonly property string timeText: {
        if (!batteryAvailable)
            return "";

        let seconds = 0;
        let prefix = "";
        if (charging) {
            seconds = Number(battery.timeToFull);
            prefix = "约 ";
        } else if (discharging) {
            seconds = Number(battery.timeToEmpty);
            prefix = "预计可用 ";
        }
        if (!isFinite(seconds) || seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.max(1, Math.round((seconds % 3600) / 60));
        if (hours > 0)
            return `${prefix}${hours} 小时 ${minutes} 分钟`;

        return `${prefix}${minutes} 分钟`;
    }
    readonly property string chargeLimitDescription: {
        if (!chargeLimitSupported)
            return "当前设备不支持充电保护";

        if ((chargeSettingsSupported & 4) !== 0)
            return "由设备固件管理充电上限";

        if (chargeEndThreshold > 0 && chargeStartThreshold > 0)
            return `${chargeStartThreshold}% 开始 · ${chargeEndThreshold}% 停止`;

        if (chargeEndThreshold > 0)
            return `充至 ${chargeEndThreshold}% 后停止`;

        return "限制满充以延缓电池老化";
    }
    property alias caffeineEnabled: policySettings.caffeineEnabled
    property alias screenTimeoutMinutes: policySettings.screenTimeoutMinutes
    property alias autoLockDelayMinutes: policySettings.autoLockDelayMinutes
    property alias lockScreenTimeoutMinutes: policySettings.lockScreenTimeoutMinutes
    property alias suspendTimeoutMinutes: policySettings.suspendTimeoutMinutes
    readonly property string screenTimeoutLabel: formatDuration(screenTimeoutMinutes)
    readonly property string autoLockDelayLabel: formatLockDelay(autoLockDelayMinutes)
    readonly property string lockScreenTimeoutLabel: formatDuration(lockScreenTimeoutMinutes)
    readonly property string suspendTimeoutLabel: formatDuration(suspendTimeoutMinutes)
    readonly property bool autoLockEnabled: screenTimeoutMinutes > 0 && autoLockDelayMinutes >= 0
    readonly property real autoLockTotalMinutes: autoLockEnabled ? screenTimeoutMinutes + autoLockDelayMinutes : 0
    readonly property string idlePolicySummary: caffeineEnabled ? "Caffeine 已开启" : `${screenTimeoutLabel}熄屏 · ${autoLockDelayLabel}锁定`
    property string batteryObjectPath: ""
    property bool chargeLimitSupported: false
    property bool chargeLimitEnabled: false
    property int chargeSettingsSupported: 0
    property int chargeStartThreshold: 0
    property int chargeEndThreshold: 0
    property bool batteryAwareSupported: false
    property bool batteryAwareEnabled: false
    property bool canSuspend: true
    property bool canHibernate: false
    property bool managementReady: false
    property bool refreshBusy: false
    property bool chargeLimitBusy: false
    property bool batteryAwareBusy: false
    property string statusText: ""
    property bool statusError: false
    property string displayState: "on"
    readonly property bool screenBlanked: displayState !== "on"
    readonly property bool activeBlanked: displayState === "active-off"
    property bool activeBlankPending: false
    property bool activeWakePending: false
    property real passiveWakeGraceUntil: 0
    property string queuedDisplayAction: ""
    property string pendingSleepAction: ""
    property bool idleMonitorsArmed: false
    property bool idleMonitorsRearming: false
    property int idleMonitorGeneration: 0
    readonly property string displayPowerHelper: Quickshell.env("HOME") + "/.config/my-desk/bin/desk-display-power"

    function normalizeMinutes(value) {
        const numeric = Number(value);
        if (!isFinite(numeric) || numeric < 0)
            return 0;

        return Math.min(240, Math.round(numeric * 100) / 100);
    }

    function formatDuration(minutes) {
        const value = Number(minutes);
        if (!isFinite(value) || value <= 0)
            return "永不";

        if (value < 1)
            return `${Math.round(value * 60)} 秒后`;

        if (value >= 60 && value % 60 === 0)
            return `${Math.round(value / 60)} 小时后`;

        return `${Math.round(value)} 分钟后`;
    }

    function normalizeAutoLockDelay(value) {
        const numeric = Number(value);
        if (!isFinite(numeric) || numeric < 0)
            return -1;

        return root.normalizeMinutes(numeric);
    }

    function formatLockDelay(minutes) {
        const value = Number(minutes);
        if (!isFinite(value) || value < 0)
            return "永不";

        if (value === 0)
            return "立即";

        return root.formatDuration(value);
    }

    function setCaffeine(enabled) {
        const value = !!enabled;
        policySettings.caffeineEnabled = value;
        policySettings.setValue("caffeineEnabled", value);
        policySettings.sync();
        if (policySettings.caffeineEnabled && root.displayState === "passive-off")
            root.wakePassiveDisplays();

    }

    function toggleCaffeine() {
        root.setCaffeine(!root.caffeineEnabled);
    }

    function setScreenTimeout(minutes) {
        const value = root.normalizeMinutes(minutes);
        policySettings.screenTimeoutMinutes = value;
        policySettings.setValue("screenTimeoutMinutes", value);
        policySettings.sync();
    }

    function setSuspendTimeout(minutes) {
        const value = root.normalizeMinutes(minutes);
        policySettings.suspendTimeoutMinutes = value;
        policySettings.setValue("suspendTimeoutMinutes", value);
        policySettings.sync();
    }

    function setAutoLockDelay(minutes) {
        const value = root.normalizeAutoLockDelay(minutes);
        policySettings.autoLockDelayMinutes = value;
        policySettings.setValue("autoLockDelayMinutes", value);
        policySettings.sync();
    }

    function setLockScreenTimeout(minutes) {
        const value = root.normalizeMinutes(minutes);
        policySettings.lockScreenTimeoutMinutes = value;
        policySettings.setValue("lockScreenTimeoutMinutes", value);
        policySettings.sync();
    }

    function rearmIdleMonitors() {
        root.idleMonitorsRearming = true;
        root.idleMonitorsArmed = false;
        idleRearmTimer.restart();
    }

    function blankDisplays() {
        root.passiveBlankDisplays();
    }

    function passiveBlankDisplays() {
        if (root.activeBlanked || root.activeBlankPending || root.displayState !== "on")
            return ;

        if (!WidgetState.sessionLocked && root.caffeineEnabled)
            return ;

        root.displayState = WidgetState.sessionLocked ? "locked-off" : "passive-off";
        Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
    }

    function wakePassiveDisplays() {
        if (root.displayState !== "passive-off" && root.displayState !== "locked-off")
            return ;

        root.displayState = "on";
        root.passiveWakeGraceUntil = Date.now() + 800;
        Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
    }

    function runDisplayHelper(action) {
        if (activeDisplayProcess.running) {
            root.queuedDisplayAction = action;
            return ;
        }
        activeDisplayProcess.requestedAction = action;
        activeDisplayProcess.running = true;
    }

    function startActiveBlank() {
        if (!root.activeBlankPending || !WidgetState.sessionLocked)
            return ;

        activeBlankSecureTimer.stop();
        root.runDisplayHelper("off");
    }

    function requestActiveBlank() {
        if (root.activeBlanked || root.activeBlankPending)
            return ;

        if (Date.now() < root.passiveWakeGraceUntil)
            return ;

        root.activeBlankPending = true;
        WidgetState.requestLock("active-blank");
        if (WidgetState.sessionLocked)
            root.startActiveBlank();
        else
            activeBlankSecureTimer.restart();
    }

    function requestActiveWake() {
        root.activeBlankPending = false;
        activeBlankSecureTimer.stop();
        root.activeWakePending = true;
        root.runDisplayHelper("on");
    }

    function toggleActiveBlank() {
        if (root.activeBlanked || root.activeBlankPending || root.activeWakePending) {
            root.requestActiveWake();
            return ;
        }
        root.requestActiveBlank();
    }

    function forceDisplaysOn() {
        if (root.activeBlanked || root.activeBlankPending || root.activeWakePending) {
            root.requestActiveWake();
            return ;
        }
        root.wakePassiveDisplays();
        Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
    }

    function wakeDisplays() {
        root.forceDisplaysOn();
    }

    function requestSleep(action) {
        if (sleepProcess.running || sleepDelayTimer.running)
            return ;

        root.pendingSleepAction = action;
        WidgetState.requestLock("sleep");
        sleepDelayTimer.restart();
    }

    function showStatus(message, isError) {
        root.statusText = message;
        root.statusError = !!isError;
        statusTimer.restart();
    }

    function refreshManagementState() {
        if (!refreshProcess.running)
            refreshProcess.running = true;

    }

    function setProfile(key) {
        switch (key) {
        case "power-saver":
            PowerProfiles.profile = PowerProfile.PowerSaver;
            break;
        case "performance":
            if (PowerProfiles.hasPerformanceProfile)
                PowerProfiles.profile = PowerProfile.Performance;

            break;
        default:
            PowerProfiles.profile = PowerProfile.Balanced;
            break;
        }
    }

    function setBatteryAware(enabled) {
        if (!batteryAwareSupported || batteryAwareBusy)
            return ;

        batteryAwareProcess.requestedState = enabled;
        batteryAwareProcess.running = true;
    }

    function setChargeLimit(enabled) {
        if (!chargeLimitSupported || chargeLimitBusy || batteryObjectPath === "")
            return ;

        chargeLimitProcess.requestedState = enabled;
        chargeLimitProcess.running = true;
    }

    function runSessionAction(action) {
        switch (action) {
        case "suspend":
            if (canSuspend)
                root.requestSleep("suspend");

            break;
        case "hibernate":
            if (canHibernate)
                root.requestSleep("hibernate");

            break;
        case "logout":
            Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    Component.onCompleted: {
        if (policySettings.policyVersion < 1) {
            policySettings.caffeineEnabled = false;
            policySettings.screenTimeoutMinutes = 10;
            policySettings.suspendTimeoutMinutes = 30;
            policySettings.policyVersion = 1;
            policySettings.setValue("caffeineEnabled", false);
            policySettings.setValue("screenTimeoutMinutes", 10);
            policySettings.setValue("suspendTimeoutMinutes", 30);
            policySettings.setValue("policyVersion", 1);
            policySettings.sync();
        }
        if (policySettings.policyVersion < 2) {
            policySettings.autoLockDelayMinutes = 5;
            policySettings.lockScreenTimeoutMinutes = 0.5;
            policySettings.policyVersion = 2;
            policySettings.setValue("autoLockDelayMinutes", 5);
            policySettings.setValue("lockScreenTimeoutMinutes", 0.5);
            policySettings.setValue("policyVersion", 2);
            policySettings.sync();
        }
        root.rearmIdleMonitors();
        // 主动熄屏会在 runtime 目录留下原始背光值。若 Shell 异常退出，
        // 冷启动时优先恢复，确保不会把用户困在零背光状态。
        root.runDisplayHelper("recover");
        refreshManagementState();
    }

    Settings {
        id: policySettings

        property bool caffeineEnabled: false
        property real screenTimeoutMinutes: 10
        property real autoLockDelayMinutes: 5
        property real lockScreenTimeoutMinutes: 0.5
        property real suspendTimeoutMinutes: 30
        property int policyVersion: 0

        category: "idle-policy"
        location: "file://" + Quickshell.stateDir + "/power-policy.ini"
        onCaffeineEnabledChanged: root.rearmIdleMonitors()
        onScreenTimeoutMinutesChanged: root.rearmIdleMonitors()
        onAutoLockDelayMinutesChanged: root.rearmIdleMonitors()
        onLockScreenTimeoutMinutesChanged: root.rearmIdleMonitors()
        onSuspendTimeoutMinutesChanged: root.rearmIdleMonitors()
    }

    Connections {
        function onSessionLockedChanged() {
            if (WidgetState.sessionLocked) {
                if (root.displayState === "passive-off")
                    root.displayState = "locked-off";

                if (root.activeBlankPending)
                    root.startActiveBlank();

            } else {
                root.activeBlankPending = false;
                if (root.activeBlanked || root.activeWakePending)
                    root.requestActiveWake();
                else if (root.displayState === "locked-off")
                    root.wakePassiveDisplays();
            }
            root.rearmIdleMonitors();
        }

        target: WidgetState
    }

    Timer {
        id: idleRearmTimer

        interval: 100
        repeat: false
        onTriggered: {
            root.idleMonitorsRearming = false;
            root.idleMonitorsArmed = true;
            root.idleMonitorGeneration++;
        }
    }

    IdleMonitor {
        id: screenIdleMonitor

        enabled: root.idleMonitorsArmed && !WidgetState.sessionLocked && !root.activeBlanked && !root.caffeineEnabled && root.screenTimeoutMinutes > 0
        timeout: Math.max(1, root.screenTimeoutMinutes * 60)
        respectInhibitors: true
        onIsIdleChanged: {
            if (root.idleMonitorsRearming)
                return ;

            if (isIdle)
                root.blankDisplays();
            else
                root.wakeDisplays();
        }
    }

    IdleMonitor {
        id: autoLockIdleMonitor

        enabled: root.idleMonitorsArmed && !WidgetState.sessionLocked && !root.activeBlanked && !root.caffeineEnabled && root.autoLockEnabled
        timeout: Math.max(1, root.autoLockTotalMinutes * 60)
        respectInhibitors: true
        onIsIdleChanged: {
            if (root.idleMonitorsRearming)
                return ;

            if (isIdle)
                WidgetState.requestLock("idle");

        }
    }

    IdleMonitor {
        id: lockScreenIdleMonitor

        enabled: root.idleMonitorsArmed && WidgetState.sessionLocked && !root.activeBlanked && root.lockScreenTimeoutMinutes > 0
        timeout: Math.max(1, root.lockScreenTimeoutMinutes * 60)
        respectInhibitors: false
        onIsIdleChanged: {
            if (root.idleMonitorsRearming)
                return ;

            if (isIdle)
                root.passiveBlankDisplays();
            else
                root.wakePassiveDisplays();
        }
    }

    IdleMonitor {
        id: suspendIdleMonitor

        enabled: root.idleMonitorsArmed && !root.caffeineEnabled && root.suspendTimeoutMinutes > 0 && root.canSuspend
        timeout: Math.max(1, root.suspendTimeoutMinutes * 60)
        respectInhibitors: true
        onIsIdleChanged: {
            if (root.idleMonitorsRearming)
                return ;

            if (isIdle)
                root.requestSleep("suspend");

        }
    }

    IpcHandler {
        function status() : string {
            return JSON.stringify({
                "caffeine": root.caffeineEnabled,
                "screenTimeoutMinutes": root.screenTimeoutMinutes,
                "autoLockDelayMinutes": root.autoLockDelayMinutes,
                "autoLockTotalMinutes": root.autoLockTotalMinutes,
                "lockScreenTimeoutMinutes": root.lockScreenTimeoutMinutes,
                "suspendTimeoutMinutes": root.suspendTimeoutMinutes,
                "displayState": root.displayState,
                "screenBlanked": root.screenBlanked,
                "sessionLocked": WidgetState.sessionLocked,
                "lockPending": WidgetState.lockPending,
                "activeBlankPending": root.activeBlankPending,
                "activeWakePending": root.activeWakePending,
                "idleMonitorsArmed": root.idleMonitorsArmed,
                "idleMonitorsRearming": root.idleMonitorsRearming,
                "idleMonitorGeneration": root.idleMonitorGeneration,
                "screenMonitorEnabled": screenIdleMonitor.enabled,
                "screenMonitorTimeout": screenIdleMonitor.timeout,
                "screenMonitorIdle": screenIdleMonitor.isIdle,
                "autoLockMonitorEnabled": autoLockIdleMonitor.enabled,
                "autoLockMonitorTimeout": autoLockIdleMonitor.timeout,
                "autoLockMonitorIdle": autoLockIdleMonitor.isIdle,
                "lockScreenMonitorEnabled": lockScreenIdleMonitor.enabled,
                "lockScreenMonitorTimeout": lockScreenIdleMonitor.timeout,
                "lockScreenMonitorIdle": lockScreenIdleMonitor.isIdle,
                "suspendMonitorEnabled": suspendIdleMonitor.enabled,
                "suspendMonitorTimeout": suspendIdleMonitor.timeout,
                "suspendMonitorIdle": suspendIdleMonitor.isIdle
            });
        }

        function setCaffeine(enabled: bool) : string {
            root.setCaffeine(enabled);
            return enabled ? "CAFFEINE_ENABLED" : "CAFFEINE_DISABLED";
        }

        function toggleCaffeine() : string {
            root.toggleCaffeine();
            return root.caffeineEnabled ? "CAFFEINE_ENABLED" : "CAFFEINE_DISABLED";
        }

        function setScreenTimeout(minutes: real) : string {
            root.setScreenTimeout(minutes);
            return root.screenTimeoutLabel;
        }

        function setAutoLockDelay(minutes: real) : string {
            root.setAutoLockDelay(minutes);
            return root.autoLockDelayLabel;
        }

        function setLockScreenTimeout(minutes: real) : string {
            root.setLockScreenTimeout(minutes);
            return root.lockScreenTimeoutLabel;
        }

        function setSuspendTimeout(minutes: real) : string {
            root.setSuspendTimeout(minutes);
            return root.suspendTimeoutLabel;
        }

        function toggleActiveBlank() : string {
            const waking = root.activeBlanked || root.activeBlankPending || root.activeWakePending;
            root.toggleActiveBlank();
            return waking ? "ACTIVE_WAKE_REQUESTED" : "ACTIVE_BLANK_REQUESTED";
        }

        function forceDisplayOn() : string {
            root.forceDisplaysOn();
            return "DISPLAY_ON_REQUESTED";
        }

        target: "power-policy"
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refreshManagementState()
    }

    Timer {
        id: refreshDelay

        interval: 500
        repeat: false
        onTriggered: root.refreshManagementState()
    }

    Timer {
        id: statusTimer

        interval: 3200
        repeat: false
        onTriggered: root.statusText = ""
    }

    Timer {
        id: activeBlankSecureTimer

        interval: 3500
        repeat: false
        onTriggered: {
            if (!root.activeBlankPending || WidgetState.sessionLocked)
                return ;

            root.activeBlankPending = false;
            WidgetState.cancelLockRequest();
            root.showStatus("锁屏未确认，已取消主动熄屏", true);
        }
    }

    Timer {
        id: activeBlankReassertTimer

        interval: 3000
        repeat: true
        running: root.activeBlanked && !root.activeWakePending
        onTriggered: Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }

    Timer {
        id: sleepDelayTimer

        interval: 850
        repeat: false
        onTriggered: sleepProcess.running = true
    }

    Process {
        id: sleepProcess

        command: ["systemctl", root.pendingSleepAction]
        onExited: (exitCode, exitStatus) => {
            root.pendingSleepAction = "";
            root.wakeDisplays();
        }
    }

    Process {
        id: activeDisplayProcess

        property string requestedAction: "status"

        command: [root.displayPowerHelper, requestedAction]
        onExited: (exitCode, exitStatus) => {
            const completedAction = requestedAction;
            if (completedAction === "off") {
                root.activeBlankPending = false;
                if (exitCode === 0) {
                    root.activeWakePending = false;
                    root.displayState = "active-off";
                } else {
                    root.displayState = "on";
                    root.showStatus("主动熄屏失败，背光已恢复", true);
                    root.runDisplayHelper("on");
                }
            } else if (completedAction === "on" || completedAction === "recover") {
                root.activeBlankPending = false;
                root.activeWakePending = false;
                root.displayState = "on";
                root.passiveWakeGraceUntil = Date.now() + 800;
                if (exitCode !== 0)
                    root.showStatus("背光恢复失败，请使用紧急恢复快捷键", true);

            }
            root.rearmIdleMonitors();
            const nextAction = root.queuedDisplayAction;
            root.queuedDisplayAction = "";
            if (nextAction !== "" && nextAction !== completedAction)
                Qt.callLater(() => {
                root.runDisplayHelper(nextAction);
            });

        }
    }

    Process {
        id: refreshProcess

        command: ["bash", "-lc", `
            battery_path=$(upower -e 2>/dev/null | grep '/battery_' | head -n 1)
            case "$battery_path" in
                /org/freedesktop/UPower/devices/battery_*) ;;
                *) battery_path="" ;;
            esac
            printf 'battery_path=%s\n' "$battery_path"

            if [ -n "$battery_path" ]; then
                for property in ChargeThresholdSupported ChargeThresholdEnabled ChargeThresholdSettingsSupported ChargeStartThreshold ChargeEndThreshold; do
                    value=$(busctl get-property org.freedesktop.UPower "$battery_path" org.freedesktop.UPower.Device "$property" 2>/dev/null | awk '{print $2}')
                    printf '%s=%s\n' "$property" "$value"
                done
            fi

            if powerprofilesctl get >/dev/null 2>&1; then
                printf 'battery_aware_supported=true\n'
                if powerprofilesctl query-battery-aware 2>/dev/null | grep -qi 'true'; then
                    printf 'battery_aware_enabled=true\n'
                else
                    printf 'battery_aware_enabled=false\n'
                fi
            else
                printf 'battery_aware_supported=false\n'
            fi

            can_suspend=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend 2>/dev/null | grep -Eo 'yes|challenge' | head -n 1)
            can_hibernate=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null | grep -Eo 'yes|challenge' | head -n 1)
            [ -n "$can_suspend" ] && printf 'can_suspend=true\n' || printf 'can_suspend=false\n'
            [ -n "$can_hibernate" ] && printf 'can_hibernate=true\n' || printf 'can_hibernate=false\n'
        `]
        onStarted: root.refreshBusy = true
        onExited: (exitCode, exitStatus) => {
            root.refreshBusy = false;
            root.managementReady = exitCode === 0;
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const line = data.trim();
                const separator = line.indexOf("=");
                if (separator < 0)
                    return ;

                const key = line.substring(0, separator);
                const value = line.substring(separator + 1);
                switch (key) {
                case "battery_path":
                    root.batteryObjectPath = value;
                    break;
                case "ChargeThresholdSupported":
                    root.chargeLimitSupported = value === "true";
                    break;
                case "ChargeThresholdEnabled":
                    root.chargeLimitEnabled = value === "true";
                    break;
                case "ChargeThresholdSettingsSupported":
                    root.chargeSettingsSupported = parseInt(value) || 0;
                    break;
                case "ChargeStartThreshold":
                    root.chargeStartThreshold = parseInt(value) || 0;
                    break;
                case "ChargeEndThreshold":
                    root.chargeEndThreshold = parseInt(value) || 0;
                    break;
                case "battery_aware_supported":
                    root.batteryAwareSupported = value === "true";
                    break;
                case "battery_aware_enabled":
                    root.batteryAwareEnabled = value === "true";
                    break;
                case "can_suspend":
                    root.canSuspend = value === "true";
                    break;
                case "can_hibernate":
                    root.canHibernate = value === "true";
                    break;
                }
            }
        }

    }

    Process {
        id: chargeLimitProcess

        property bool requestedState: false

        command: ["busctl", "call", "org.freedesktop.UPower", root.batteryObjectPath, "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", requestedState ? "true" : "false"]
        onStarted: root.chargeLimitBusy = true
        onExited: (exitCode, exitStatus) => {
            root.chargeLimitBusy = false;
            root.showStatus(exitCode === 0 ? (requestedState ? "已启用充电保护" : "已切换为完全充满") : "充电策略切换失败", exitCode !== 0);
            refreshDelay.restart();
        }
    }

    Process {
        id: batteryAwareProcess

        property bool requestedState: false

        command: ["powerprofilesctl", "configure-battery-aware", requestedState ? "--enable" : "--disable"]
        onStarted: root.batteryAwareBusy = true
        onExited: (exitCode, exitStatus) => {
            root.batteryAwareBusy = false;
            root.showStatus(exitCode === 0 ? (requestedState ? "已启用电源模式自动切换" : "已关闭电源模式自动切换") : "自动切换设置失败", exitCode !== 0);
            refreshDelay.restart();
        }
    }

}
