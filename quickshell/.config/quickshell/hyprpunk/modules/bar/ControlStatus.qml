import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Networking
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// What the control pill shows: a dot when a background app waits for you, network (a
// spinner while it connects), caffeine, volume and battery. The bar and the lock screen
// both use it.
RowLayout {
    id: status

    // Behind the Ethernet padlock badge: the pill's own color.
    property color badgeColor: Colors.panel
    // On the bar only: the lock screen gives no way to reach the app.
    property bool showsTrayAttention: false

    function networkIcon() {
        const device = NetworkStatus.device;
        if (device === null)
            return "signal_wifi_off";

        if (device.type === DeviceType.Wired)
            return device.connected ? "lan" : "settings_ethernet";

        const network = NetworkStatus.activeWifi;
        return Icons.wifi(network !== null ? network.signalStrength : 0, device.connected && Vpn.connection !== null);
    }

    spacing: Metrics.spacing.normal

    // A background app waits for you: it's in the control center.
    Rectangle {
        visible: status.showsTrayAttention && Tray.needsAttention
        Layout.preferredWidth: 7
        Layout.preferredHeight: 7
        radius: 3.5
        color: Colors.primary
    }

    // Spinner in place of the icon while NetworkManager connects (VPN included).
    Item {
        implicitWidth: NetworkStatus.connecting ? 16 : networkLabel.implicitWidth
        implicitHeight: networkLabel.implicitHeight

        Icon {
            id: networkLabel

            visible: !NetworkStatus.connecting
            text: status.networkIcon()
            size: Metrics.text.title
        }

        Shape {
            id: networkSpinner

            property real sweep: 90

            visible: NetworkStatus.connecting
            anchors.centerIn: parent
            width: 14
            height: 14
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.alpha(Colors.primary, 0.25)
                strokeWidth: 2

                PathAngleArc {
                    centerX: networkSpinner.width / 2
                    centerY: networkSpinner.height / 2
                    radiusX: networkSpinner.width / 2 - 1
                    radiusY: networkSpinner.height / 2 - 1
                    startAngle: 0
                    sweepAngle: 360
                }

            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.primary
                strokeWidth: 2
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: networkSpinner.width / 2
                    centerY: networkSpinner.height / 2
                    radiusX: networkSpinner.width / 2 - 1
                    radiusY: networkSpinner.height / 2 - 1
                    startAngle: -90
                    sweepAngle: networkSpinner.sweep
                }

            }

            // A plain animation on purpose: an Animator here held the whole shell
            // to 30 frames a second, and everything played in slow motion.
            RotationAnimation on rotation {
                running: networkSpinner.visible
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }

            // The arc stretches and shrinks as it turns.
            SequentialAnimation on sweep {
                running: networkSpinner.visible
                loops: Animation.Infinite

                NumberAnimation {
                    to: 270
                    duration: 700
                    easing.type: Easing.InOutCubic
                }

                NumberAnimation {
                    to: 40
                    duration: 700
                    easing.type: Easing.InOutCubic
                }

            }

        }

        // No locked Ethernet glyph in Material Design: a padlock badge instead.
        Rectangle {
            visible: NetworkStatus.wiredLocked && !NetworkStatus.connecting
            anchors.right: networkLabel.right
            anchors.bottom: networkLabel.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: 1
            width: 11
            height: 11
            radius: width / 2
            color: status.badgeColor

            Icon {
                anchors.centerIn: parent
                text: "lock"
                size: 9
            }

        }

    }

    // Caffeine on: the computer stays awake.
    Icon {
        size: Metrics.text.title
        visible: ShellState.caffeine
        text: "coffee"
    }

    IconText {
        visible: Audio.sink !== null
        icon: Icons.volume(Audio.volume, Audio.muted)
        text: Audio.volume + "%"
    }

    IconText {
        id: batteryPill

        visible: Battery.present
        // Red only when it's running out (the settings' low level), not while charging.
        color: Battery.onBattery && Battery.percent <= BatterySettings.low ? Colors.red : Colors.primary
        icon: Icons.battery(Battery.device.percentage, Battery.onBattery)
        text: Battery.percent + "%"

        // Pulses once it's critical.
        SequentialAnimation on opacity {
            running: Battery.critical
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    batteryPill.opacity = 1;

            }

            NumberAnimation {
                to: 0.4
                duration: 900
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }

        }

    }

}
