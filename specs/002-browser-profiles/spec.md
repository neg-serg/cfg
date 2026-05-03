# Browser Profiles with Persistent Sessions

**Branch**: `002-browser-profiles`
**Created**: 2026-05-04
**Status**: Draft

## Input

Multiple Zen Browser profiles with isolated persistent data (cookies, localStorage, sessions), cookie import from other browsers, profile switching via CLI and Hyprland keybind, Salt-managed profile templates with pre-configured settings.

## User Stories

| # | Title | Priority |
|---|-------|----------|
| US-1 | List and switch Zen profiles | P1 |
| US-2 | Create new Zen profile with isolated storage | P1 |
| US-3 | Import cookies from Chromium/Firefox/Floorp into a profile | P2 |
| US-4 | Salt deploys pre-configured profile templates | P2 |
| US-5 | Hyprland keybind launches profile switch picker | P3 |

## Functional Requirements

| ID | Description |
|----|-------------|
| FR-001 | `zen-profile list` outputs all Zen profiles with default marker |
| FR-002 | `zen-profile switch <name>` sets profile as default in profiles.ini |
| FR-003 | `zen-profile create <name>` creates new profile via `zen-browser -CreateProfile` |
| FR-004 | `zen-profile cookies <name> --from chromium|firefox|floorp` imports cookies via browser-cookie3 |
| FR-005 | Salt state deploys `zen-profile` script and creates predefined profiles from data YAML |
| FR-006 | Hyprland `Super+Alt+P` opens rofi profile picker calling `zen-profile switch` |
| FR-007 | Each profile has isolated `storage/`, `cookies.sqlite`, `places.sqlite` |

## Success Criteria

| ID | Metric |
|----|--------|
| SC-001 | Profile switch takes under 2 seconds (CLI) |
| SC-002 | Cookie import from Chromium completes under 5 seconds |
| SC-003 | Salt creates ≥2 predefined profiles (personal, work) with unique settings |
