.pragma library

function fuzzySearch(inputText, appName) {
    let lowerInput = inputText.toLowerCase();
    let lowerName = appName.toLowerCase();
    let inputIndex = 0;

    for (let i = 0; i < lowerName.length; i++) {
        if (lowerName[i] === lowerInput[inputIndex]) {
            inputIndex++;
        }
        if (inputIndex === lowerInput.length) {
            return true;
        }
    }
    return false;
}

function updateFilter(inputText, DesktopEntries) {
    let lowerInput = (inputText || "").toLowerCase();
    const apps = DesktopEntries.applications.values;
    let filterApps = [];

    if (lowerInput === "") {
        filterApps = apps;
    } else {
        filterApps = apps.filter((app) => fuzzySearch(lowerInput, app.name));
    }

    // 过滤掉不可见的后台挂件
    filterApps = filterApps.filter(app => !app.noDisplay);

    // 强制按首字母 A-Z 排序
    filterApps.sort((a, b) => {
        let nameA = a.name ? a.name.toLowerCase() : "";
        let nameB = b.name ? b.name.toLowerCase() : "";
        if (nameA < nameB) return -1;
        if (nameA > nameB) return 1;
        return 0;
    });

    let result = [];
    for (let i = 0; i < filterApps.length; i++) {
        let app = filterApps[i];
        
        let rawIcon = app.icon || "";
        let finalPath = rawIcon;

        // 优先交给系统图标主题解析，避免依赖作者机器上的特定图标主题路径。
        if (rawIcon && rawIcon.indexOf("/") === -1) {
            finalPath = "image://icon/" + rawIcon;
        }

        result.push({
            name: app.name,
            icon: finalPath,         // 传给 QML 的主要路径（Tela 的绝对路径）
            fallbackIcon: rawIcon,   // 【重点】把原始图标名也传过去，留作兜底备用！
            appObj: app 
        });
        
        if (result.length >= 50) break;
    }

    return result;
}
