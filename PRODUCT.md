# HomeControl

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS menu-bar application. The skill's generic platform vocabulary does not include macOS; this value records the actual target.

## Stack

SwiftUI and AppKit, with Foundation networking, macOS Keychain and Sparkle for software updates. Native implementation for macOS.

## Users

The resident of a home already managed by Home Assistant, using a Mac and wanting quick access to home controls.

## Product Purpose

Control Home Assistant devices from a compact menu-bar panel, following the supplied air-conditioner reference.

## Operating Context

Each user connects their own Home Assistant instance. Credentials are stored locally in macOS Keychain. The interface follows the Mac's language, with en-US and pt-BR and English fallback. Device and area names supplied by Home Assistant stay unchanged. The repository contains synthetic demonstration fixtures and no configured household.

## Capabilities and Constraints

- Signed software updates through the project GitHub Releases HTTPS feed. The repository includes the public endpoint and verification key; the private signing key stays outside the repository.
- Detailed climate controls, plus lights, switches, fans, covers, and scenes.
- Three labelled tabs: Ar-condicionado, Cômodos, Favoritos. One fixed-width menu-bar icon, without changing temperature text in the system bar.
- Daily controls and environmental readings lead the room view. Consumption, schedules, maintenance, configuration, diagnostics and unknown readings are separate collapsed sections. Local, per-server classification/hiding overrides are reversible and do not modify HA entities.
- Consumption retains the device, unit and supplied period; accumulated energy is separate from instantaneous power, with no synthetic aggregate totals.
- Display only controls supported by each entity.
- Climate airflow follows reported fan speed and horizontal swing. Unknown or automatic fan speed uses a moderate visual fallback; this is not an electrical-power measurement. Motion pauses when hidden, off or disconnected; Reduce Motion retains a static indication.
- Live state updates; explicit connection and command errors.
- Room overview matching Home Assistant areas, mixed controls/readings, stable room IDs, and detailed controls with return navigation.
- Automatic registry updates through events, plus reconciliation every minute. A failed metadata load is not represented as an empty home.
- CLI inventory and reversible room assignment plans, with private before/after metadata backups and preconditions protecting concurrent edits.
- Store access tokens in macOS Keychain, never in source or plain preferences.
- Clearly identified demonstration data until connected; opening a preview must not send commands to a real home.
- No locks, alarms, garage doors, or other security controls in the initial scope.
- Desktop widgets: a configurable large widget with up to four ordered controls (lights, switches, fans, climate and scenes), plus a medium single-device widget using the same catalog. Selection belongs to each widget; removing an entity or changing accounts never selects a replacement. The single-device widget can select lights and scenes as well as climate; climate retains its temperature artwork, direct step adjustments and supported power actions. WidgetKit reads display-only shared data; credential access and service execution stay in the host process. Included in release 0.4.0.

## Brand Commitments

The supplied screenshot is the composition authority: a compact panel, warm neutral controls, a prominent temperature, and an air-conditioner image. The user asked to build this directly, then explicitly requested glassmorphism. Use genuine native macOS backdrop blur, smoked translucent surfaces, and fine glass edge highlights while preserving that composition.

## Demonstration and Verification

Demonstration rooms, entities and readings are synthetic and explicitly labelled. Protocol tests use a local simulated server on loopback. Live-home inventories, screenshots, logs and account configuration are excluded from the repository.

## Product Principles

- A few seconds from opening the menu to the desired control.
- The server remains the source of truth for device states.
- Unsupported capabilities never appear as working controls.
- Keep setup and failures understandable without exposing implementation details.
