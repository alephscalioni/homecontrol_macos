# Home controls widgets

Mode: Operate.

Native macOS WidgetKit medium single-device widget and large configurable widget with up to four ordered controls. Both use the same supported-device catalog: visible lights, switches, fans, climate and scenes. Items classified as maintenance, configuration or diagnostics are offered only when marked as favorites.

The visual language inherits HomeControl's smoked-glass palette and system typography. The single-device climate card retains the air-conditioner artwork, target and ambient temperature, supported power actions and temperature steps. Other devices show their name, room, type and supported action. The large widget uses up to two columns. Unsupported or disconnected actions are disabled; a removed or other-account item never selects a replacement.

Native cards explain right-click → Edit. The demonstration window instead offers Change item / Change items, searchable options and per-item Change, remove and reorder actions. A full four-item selection supports direct replacement without first removing an item. Search considers name, room and device type. The editor is a separate SwiftUI view with bindings so replacement state updates immediately.

Widget actions use App Intents without intentionally opening a separate app panel. The extension reads display-only shared data; credentials and Home Assistant service execution stay in the host. No slider, expanded Control Center submenu or continuous widget animation is offered. The token, server address and household configuration are excluded from source and distributable app bundles.

Validation covers synthetic device capabilities, identity and selection rules, signed native builds, localized shared SwiftUI views and demonstration commands through the host bridge. Desktop configuration restoration and actual widget AppIntent dispatch need a separate native runtime check; demonstration evidence does not prove them.
