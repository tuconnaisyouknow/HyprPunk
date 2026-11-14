pragma Singleton

import QtQuick
import Quickshell

// The status icons the bar, the island and the control center share, so the same
// level always gets the same glyph.
Singleton {
    // volume in %, 0 to 100.
    function volume(volume, muted) {
        if (muted)
            return "";

        if (volume === 0)
            return "";

        return volume < 34 ? "" : volume < 67 ? "" : "";
    }

    // percent from 0 to 100.
    function brightness(percent) {
        const icons = ["", "", "", "", "", "", "", "", ""];
        return icons[Math.min(icons.length - 1, Math.floor(percent * icons.length / 101))];
    }

    // strength from 0 to 1. Locked while a VPN is up over the Wi-Fi.
    function wifi(strength, locked) {
        const icons = locked ? ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"] : ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        return icons[Math.max(0, Math.min(icons.length - 1, Math.floor(strength * icons.length)))];
    }

    // charge from 0 to 1. Plugged in, the same gauge gets the charging bolt.
    function battery(charge, onBattery) {
        const icons = onBattery ? ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"] : ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        return icons[Math.min(icons.length - 1, Math.floor(Math.max(0, Math.min(1, charge)) * icons.length))];
    }

    // A battery filled up to the charge limit in %, full without one.
    function chargeLimit(limit) {
        return limit >= 100 ? "󰁹" : String.fromCodePoint(0xf007a + Math.max(0, Math.min(8, Math.round(limit / 10) - 1)));
    }

    // "power-saver", "balanced" or "performance".
    function powerProfile(profile) {
        if (profile === "performance")
            return "󰓅";

        if (profile === "power-saver")
            return "󰌪";

        return "󰾅";
    }
}
