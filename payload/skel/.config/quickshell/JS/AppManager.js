.pragma library

var _freqData = {};

function setFreqData(data) {
    _freqData = data || {};
}

function getFreq(appId) {
    return _freqData[appId] || 0;
}

function recordLaunch(appId) {
    if (!appId) return
    _freqData[appId] = (_freqData[appId] || 0) + 1
}

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

function updateFilter(inputText, DesktopEntries, sortMode) {
    let lowerInput = (inputText || "").toLowerCase();
    const apps = DesktopEntries.applications.values;
    let filterApps = [];

    if (lowerInput === "") {
        filterApps = apps;
    } else {
        filterApps = apps.filter((app) => fuzzySearch(lowerInput, app.name));
    }

    filterApps = filterApps.filter(app => !app.noDisplay);

    if (sortMode === "frequent") {
        filterApps.sort((a, b) => {
            let fa = getFreq(a.id) || 0
            let fb = getFreq(b.id) || 0
            if (fa !== fb) return fb - fa
            let nameA = a.name ? a.name.toLowerCase() : "";
            let nameB = b.name ? b.name.toLowerCase() : "";
            if (nameA < nameB) return -1;
            if (nameA > nameB) return 1;
            return 0;
        });
    } else {
        filterApps.sort((a, b) => {
            let nameA = a.name ? a.name.toLowerCase() : "";
            let nameB = b.name ? b.name.toLowerCase() : "";
            if (nameA < nameB) return -1;
            if (nameA > nameB) return 1;
            return 0;
        });
    }

    let result = [];
    for (let i = 0; i < filterApps.length; i++) {
        let app = filterApps[i];
        
        let rawIcon = app.icon || "";
        let finalPath = rawIcon;

        if (rawIcon && rawIcon.indexOf("/") === -1) {
            finalPath = "image://icon/" + rawIcon;
        }

        result.push({
            id: app.id,
            name: app.name,
            icon: finalPath,
            fallbackIcon: rawIcon,
            appObj: app,
            freq: getFreq(app.id)
        });
        
        if (result.length >= 50) break;
    }

    return result;
}
