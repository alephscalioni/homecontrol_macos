# Home controls widgets

Mode: Operate.

Native macOS WidgetKit medium single-device widget and large configurable widget with up to four ordered controls. Both use the same supported-device catalog: visible lights, switches, fans, climate, cameras and scenes. Items classified as maintenance, configuration or diagnostics are offered only when marked as favorites.

The visual language inherits HomeControl's smoked-glass palette and system typography. The single-device climate card retains the air-conditioner artwork, target and ambient temperature, supported power actions and temperature steps. Other devices show their name, room, type and supported action. The large widget uses up to two columns. Unsupported or disconnected actions are disabled; a removed or other-account item never selects a replacement.

Native cards explain right-click → Edit. The demonstration window instead offers Change item / Change items, searchable options and per-item Change, remove and reorder actions. A full four-item selection supports direct replacement without first removing an item. Search considers name, room and device type. The editor is a separate SwiftUI view with bindings so replacement state updates immediately.

Power, temperature and camera refresh actions use App Intents without intentionally opening a separate app panel. The explicit camera expand action opens its live viewer. The extension reads display-only shared data; credentials and Home Assistant service execution stay in the host. No slider, expanded Control Center submenu or continuous widget animation is offered. The token, server address and household configuration are excluded from source and distributable app bundles.

Validation covers synthetic device capabilities, identity and selection rules, signed native builds, localized shared SwiftUI views and demonstration commands through the host bridge. Desktop configuration restoration and actual widget AppIntent dispatch need a separate native runtime check; demonstration evidence does not prove them.

Camera tiles use private local snapshots with the capture time, refresh and expand buttons. The host viewer preserves the full image, supports pause/reconnect and cancels the stream on close or connection change. Native widget refresh frequency remains controlled by macOS. Demo camera images are labelled synthetic test signals.

Live viewing opens a compact borderless camera panel, initially 340 × 191 points with a 16:9 aspect ratio and a size button cycling through widths of 240, 340 and 480 points. It keeps the complete frame, has a quiet title/status overlay and reveals pause, pin, size, expand and close controls on hover or keyboard focus. Window position/size and the always-on-top choice persist locally. Closing, switching display modes or changing connections cancels the previous stream.
