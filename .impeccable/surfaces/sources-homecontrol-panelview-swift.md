---
version: 1
slug: "sources-homecontrol-panelview-swift"
primary_target: "Sources/HomeControl/PanelView.swift"
related_targets: ["Sources/HomeControl/DeviceViews.swift","Sources/HomeControl/SetupView.swift"]
---

# Menu-bar panel

Mode: Operate. User-approved native macOS menu-bar controller, built directly from the supplied screenshot. The native macOS context and the screenshot govern all design decisions.

## Direction contract

THESIS: One compact remote for the user's Home Assistant devices, opened directly from the Mac menu bar.

OWN-WORLD: User-requested glassmorphism, with genuine native macOS backdrop blur, smoked translucent surfaces and fine glass edge highlights. Warm ivory type and olive-taupe selected controls; SF Symbols and San Francisco type; tactile rounded sliders.

STORY: Choose a device category and an entity, read the actual state, and change only supported settings. Setup asks for the server and a token. Demonstration data is explicitly labelled.

FIRST VIEWPORT: A 440-pixel-wide panel. Category icons along the top, device and room at upper left, circular power at upper right. A white air conditioner occupies the center. Large temperature and Eco control below, wide temperature slider, compact mode controls, then connection status and settings.

FORM: User-pinned screenshot, direct-build approval, and the subsequent explicit glassmorphism request override concept seed 974d5099. Preserve the screenshot's composition while translating its opaque surfaces to native glass. Accessibility Reduce Transparency keeps an opaque fallback.

SIGNATURE: Soft, animated airflow below the air conditioner only while it is powered on, respecting Reduce Motion. Every control reflects server capabilities; pending commands do not fabricate live states.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Acceptance

- Build an actual launchable macOS .app and open it locally.
- Match the screenshot's main climate composition and warm dark palette.
- Support climate, lights, switches, curtains, fans, scenes, and read-only sensors.
- Verify native UI in demonstration mode and protocol behavior against a local simulated Home Assistant.
- Keep production connection verification explicitly pending until the user configures their server.
