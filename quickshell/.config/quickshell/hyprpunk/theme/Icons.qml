pragma Singleton

import QtQuick
import Quickshell

// The status icons the bar, the island and the control center share, so the same
// level always gets the same Material Symbols icon (Icon draws them by name).
Singleton {
    // volume in %, 0 to 100.
    function volume(volume, muted) {
        if (muted)
            return "volume_off";

        if (volume === 0)
            return "volume_mute";

        return volume < 50 ? "volume_down" : "volume_up";
    }

    // percent from 0 to 100.
    function brightness(percent) {
        return percent < 34 ? "brightness_low" : percent < 67 ? "brightness_medium" : "brightness_high";
    }

    // strength from 0 to 1. Locked while a VPN is up over the Wi-Fi. Material has no
    // empty locked Wi-Fi, so a locked one keeps at least a bar.
    function wifi(strength, locked) {
        const icons = locked ? ["network_wifi_1_bar_locked", "network_wifi_1_bar_locked", "network_wifi_2_bar_locked", "network_wifi_3_bar_locked", "signal_wifi_4_bar_lock"] : ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"];
        return icons[Math.max(0, Math.min(icons.length - 1, Math.floor(strength * icons.length)))];
    }

    // charge from 0 to 1. Plugged in, the battery gets the charging bolt.
    function battery(charge, onBattery) {
        const icons = onBattery ? ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"] : ["battery_charging_20", "battery_charging_30", "battery_charging_50", "battery_charging_60", "battery_charging_80", "battery_charging_90", "battery_charging_full"];
        return icons[Math.min(icons.length - 1, Math.floor(Math.max(0, Math.min(1, charge)) * icons.length))];
    }

    // A battery filled up to the charge limit in %, full without one.
    function chargeLimit(limit) {
        return limit >= 100 ? "battery_full" : "battery_" + Math.max(0, Math.min(6, Math.round(limit * 7 / 100))) + "_bar";
    }

    // A Bluetooth device by the icon name BlueZ gives it.
    function bluetoothDevice(icon) {
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones"))
            return "headphones";

        if (icon.startsWith("audio"))
            return "speaker";

        if (icon.startsWith("input-mouse"))
            return "mouse";

        if (icon.startsWith("input-keyboard"))
            return "keyboard";

        if (icon.startsWith("input-gaming"))
            return "sports_esports";

        if (icon.startsWith("phone"))
            return "smartphone";

        return "bluetooth";
    }

    // "power-saver", "balanced" or "performance".
    function powerProfile(profile) {
        if (profile === "performance")
            return "speed";

        if (profile === "power-saver")
            return "eco";

        return "balance";
    }
}
