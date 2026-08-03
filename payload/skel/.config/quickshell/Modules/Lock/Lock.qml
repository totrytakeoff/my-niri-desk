import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property bool secure: sessionLock.secure

    signal secured()
    signal unlocked()

    // 1. 鉴权逻辑 (Scope)
    Scope {
        id: internalContext

        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool authenticated: false
        property string authState: "idle"

        signal authenticationSucceeded()
        signal authenticationFailed()

        function tryUnlock() {
            if (currentText === "" || unlockInProgress || authenticated)
                return false;

            showFailure = false;
            internalContext.unlockInProgress = true;
            internalContext.authState = "authenticating";
            pam.start();
            return true;
        }

        function finishUnlock() {
            // 只有 PAM 已明确认证成功时，才允许释放 Wayland Session Lock。
            if (!authenticated)
                return false;

            sessionLock.locked = false;
            internalContext.authenticated = false;
            internalContext.authState = "unlocked";
            root.unlocked();
            return true;
        }

        PamContext {
            id: pam

            configDirectory: Quickshell.env("HOME") + "/.config/quickshell/Modules/Lock/pam"
            config: "password.conf"
            onPamMessage: {
                if (this.responseRequired)
                    this.respond(internalContext.currentText);

            }
            onCompleted: (result) => {
                internalContext.unlockInProgress = false;
                if (result == PamResult.Success) {
                    internalContext.currentText = "";
                    internalContext.showFailure = false;
                    internalContext.authenticated = true;
                    internalContext.authState = "success";
                    internalContext.authenticationSucceeded();
                } else {
                    internalContext.authenticated = false;
                    internalContext.currentText = "";
                    internalContext.showFailure = true;
                    internalContext.authState = "failure";
                    internalContext.authenticationFailed();
                }
            }
        }

    }

    // 2. Wayland 锁屏
    WlSessionLock {
        id: sessionLock

        locked: true
        onSecureChanged: {
            if (secure)
                root.secured();

        }

        WlSessionLockSurface {
            // // C. 紧急出口 (右上角)
            // Rectangle {
            //     anchors.top: parent.top
            //     anchors.right: parent.right
            //     width: 150; height: 50
            //     color: "red"
            //     z: 999
            //     Text {
            //         anchors.centerIn: parent
            //         text: "紧急解锁"
            //         color: "white"
            //         font.pixelSize: 16
            //         font.bold: true
            //     }
            //     MouseArea {
            //         anchors.fill: parent
            //         onClicked: {
            //             sessionLock.locked = false
            //             root.unlocked()
            //         }
            //     }
            // }

            // A. UI 加载器
            Loader {
                id: uiLoader

                anchors.fill: parent
                // 使用 HOME 环境变量拼接标准的文件 URL
                source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/Modules/Lock/LockSurface.qml"
                onLoaded: {
                    if (item)
                        item.context = internalContext;

                }
            }

        }

    }

}
