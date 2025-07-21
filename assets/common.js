function getDeviceType() {
    const ua = navigator.userAgent;

    if (/mobile/i.test(ua)) {
        return "Mobile";
    } else if (/tablet/i.test(ua)) {
        return "Tablet";
    } else {
        return "Desktop";
    }
}

if (getDeviceType() !== "Desktop") {
    if (location.pathname !== "/") {
        location.href = "/";
    }
}

document.addEventListener("DOMContentLoaded", () => {
    if (getDeviceType() !== "Desktop") {
        const warning = document.getElementById("warning");
        if (warning) {
            warning.checked = true;
        }
    }
});