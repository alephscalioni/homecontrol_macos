# HomeControl

[Português (Brasil)](README.md)

Control your Home Assistant devices from your Mac’s menu bar. Adjust the air conditioner, turn on the lights, and reach each room’s controls without opening a browser.

The app follows your Mac’s language, with US English and Brazilian Portuguese. Your device and room names stay exactly as you set them in Home Assistant.

## Install

Requires a Mac with Apple Silicon (M1 or later) and macOS 14 or later. Your Home Assistant must already be set up and reachable from your Mac.

This version is developer-signed and distributed without Apple notarization. macOS may block it from opening.

1. [Download the latest version](https://github.com/alephscalioni/homecontrol_macos/releases/latest).
2. Extract the ZIP and move **HomeControl.app** to **Applications**.
3. Open the app. Click the house icon in the menu bar to see your controls.

To try the app before connecting your home, choose **Explore demo**. This shows sample devices.

## Connect to Home Assistant

On first launch:

1. Enter your Home Assistant address, such as `http://homeassistant.local:8123` or the HTTPS address you already use.
2. In Home Assistant, open **Profile → Security → Long-lived access tokens** and create a token named HomeControl. This code allows the app to access your home.
3. Copy the token, paste it into the app, and click **Connect to Home Assistant**.

Your devices and rooms appear after connecting. You do not need to install an additional Home Assistant integration.

## Use the controls

The app has three tabs:

- **Air conditioning:** choose a room and adjust the temperature, mode, fan speed, and airflow. Drag the temperature slider and release to confirm, or use **−** and **+**. The airflow animation follows the fan speed reported by your device.
- **Rooms:** open a room to access lights, outlets, switches, blinds, fans, and sensor readings. Click a device’s name to open its details.
- **Favorites:** keep your most-used items together. Click an item’s star to add or remove it.

Available options depend on each device’s capabilities. RGB lights support on/off and brightness. Color selection, cameras, media players, locks, and alarms do not yet have controls in the app.

## Organize your home

Rooms follow the areas set up in Home Assistant. Changes made there appear automatically in HomeControl. Items without an assigned area appear under **Unassigned**.

Everyday controls appear first in each room. Consumption, maintenance, and other readings are in sections you can expand when needed.

Use **Organize** to change an item’s classification or hide it. You can restore hidden items in the same view. These preferences are saved on this Mac.

## Update the app

When HomeControl asks about updates, allow automatic checks and select the option to download and install new versions. To check manually, open **⋯ → Check for Updates…**.

Your Home Assistant connection and preferences are kept when updating.

## Connection and privacy

Your access token is stored in **macOS Keychain**. To remove it from this Mac, open HomeControl settings and choose **Forget connection**.

If the connection drops, the app shows a notice and tries to reconnect. Controls stay unavailable until the connection returns. You can also choose **⋯ → Reconnect** to retry.
