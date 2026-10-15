# Cômodos

Mode: Operate. Extension of the approved native macOS glass panel. The user requested organizing the actual Home Assistant registry by room and seeing the same organization in the app.

## Direction contract

THESIS: Choose a room, find its controls across device categories, and return to that room after opening a detailed control.

OWN-WORLD: Inherit DESIGN.md and native glass, color, typography, spacing, symbols and focus behavior. No new visual world is introduced; the original reference and seed 974d5099 remain the governing visual authority.

STORY: A Cômodos tab shows the areas returned by Home Assistant. Open a room to see compatible entities, search all groups without exposing every technical entity by default. Toda a casa and Sem cômodo make global or unassigned entities discoverable without fabricating a location.

FIRST VIEWPORT: Within the existing 440 × 632 panel, three labelled tabs (Ar-condicionado, Cômodos, Favoritos) stay fixed. The room overview shows actual areas, daily-item counts and access to Toda a casa, Geral da casa and Sem cômodo. Each room puts controls and environment first. Consumption, routines, maintenance, configuration, diagnostics and other readings start collapsed. Organizar exposes local classification and reversible hiding. The system menu-bar icon has fixed square width.

FORM: Precise functional extension of the user-approved glass composition. Room IDs are stable; names and assignments come from Home Assistant, respecting entity overrides and device inheritance.

SIGNATURE: Changes to areas, devices and entity assignments refresh automatically through registry events, with periodic reconciliation and explicit failure states.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Acceptance

- Inspect the real HA registry through a credential-safe CLI, back up assignments, apply only justified mappings and verify them by rereading.
- Preserve entity IDs and existing device controls. Device-registry assignment propagates through inheritance; multi-room hardware may have entity-specific overrides.
- Preserve unknown/global locations without representing them as zero or inventing a room.
- In the app, show real rooms, counts, mixed controls, empty/error/loading states, detailed controls and return navigation.
- Refresh room names and assignments automatically without restarting the application.

- User refinement: avoid item overload and strange menus; keep three explicit tabs and a stable menu-bar width.
- Preserve the flowing air reference from https://x.com/icanberk/status/2109031477484937571. Airflow travels downward only when running; Reduce Motion keeps a static representation.
- Preview the selected single-setpoint temperature during drag, with a short instruction; commit only on release.

- Interaction refinement: tap the whole device row to enter details; separate power buttons remain explicit. Every collapsed section expands from its whole header, not only a small chevron.
