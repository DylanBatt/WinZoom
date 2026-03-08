# WinZoom

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![Version](https://img.shields.io/badge/version-1.0-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

WinZoom is a lightweight macOS menu bar utility that brings Windows-style Ctrl+Scroll zoom behaviour to macOS. It monitors scroll-wheel events system-wide and translates them into the standard macOS zoom shortcut (Cmd+= / Cmd+-), so any app that supports zoom responds instantly — no per-app configuration required.

---

## Features

- **Windows-style zoom** — hold a modifier key and scroll to zoom in or out in any macOS application
- **Configurable trigger key** — choose between Control (^), Command (cmd), or Option (opt)
- **Adjustable zoom speed** — ten speed levels from Slow to Turbo
- **Invertible scroll direction** — reverse the zoom direction to match your preference
- **Launch at login** — optionally start WinZoom automatically on every boot
- **Menu bar only** — no Dock icon, no clutter; lives entirely in the system menu bar
- **Accessibility permission management** — live status indicator with one-click permission request built into Settings

---

## Requirements

| Requirement | Minimum |
|---|---|
| macOS | 13.0 (Ventura) |
| Architecture | Apple Silicon / Intel (Universal) |
| Accessibility permission | Required |

---

## Installation

### Manual

1. Download the latest release from the [Releases](../../releases) page.
2. Move `WinZoom.app` to your `/Applications` folder.
3. Launch WinZoom.
4. When prompted, grant Accessibility permission in **System Settings > Privacy & Security > Accessibility**.

### Build from Source

```bash
git clone https://github.com/dylanbatt/WinZoom.git
cd WinZoom
open WinZoom.xcodeproj
```

Select the `WinZoom` scheme in Xcode and press **Cmd+R** to build and run.

---

## Usage

Once running, WinZoom appears as a mouse icon in the menu bar.

| Action | Result |
|---|---|
| Hold **Control** and scroll up | Zoom in |
| Hold **Control** and scroll down | Zoom out |
| Click the menu bar icon | Open the WinZoom menu |

The default trigger key is **Control (^)**. This can be changed at any time from the Settings window.

---

## Configuration

Open **Settings** from the menu bar icon (or press **Cmd+,** while WinZoom is active) to access the following preferences.

### Zoom

| Setting | Description | Default |
|---|---|---|
| Trigger key | Modifier key that activates zoom (Control, Command, or Option) | Control (^) |
| Zoom speed | How fast zoom steps accumulate per scroll gesture (1 = Slow, 10 = Turbo) | 5 (Normal) |
| Invert scroll direction | Reverses the zoom direction | Off |

### General

| Setting | Description | Default |
|---|---|---|
| Launch at login | Registers WinZoom as a macOS login item via SMAppService | Off |

---

## Permissions

WinZoom requires **Accessibility** permission to monitor global scroll events. This is a macOS privacy safeguard for any app that reads input outside its own windows.

To grant permission:
1. Open **Settings** from the WinZoom menu bar icon.
2. The **Accessibility Access** banner at the top of Settings will show the current state.
3. If permission is missing, click **Grant Access** — this opens the relevant pane in System Settings directly.
4. Enable WinZoom in the list and return to the app. No restart is required.

> The permission status indicator polls every 2 seconds and updates automatically as soon as access is granted or revoked.

---

## Technical Notes

- **Sandbox-compatible** — WinZoom uses `NSEvent.addGlobalMonitorForEvents`, which does not require a CGEventTap and is accepted by the Mac App Store. The trade-off is that the original scroll event cannot be consumed. In applications that handle Ctrl+Scroll natively (e.g. Google Chrome), users may observe a double-zoom step and should switch the trigger key to **Option** in Settings.
- **Zoom keystrokes** — zoom is performed by synthesising `Cmd+=` (zoom in) and `Cmd+-` (zoom out) keystrokes posted to the active session tap (`cgAnnotatedSessionEventTap`), which means any macOS application that implements the standard zoom shortcut works automatically.
- **Scroll accumulation** — a threshold accumulator normalises the difference between mouse wheels (discrete delta) and trackpads (continuous delta), ensuring consistent behaviour across input devices at all speed settings.
- **Settings persistence** — all preferences are stored in `UserDefaults` and take effect immediately without requiring an app restart.

---

## Developer

Developed by **Dylan Batt**

- Website: [dylanbatt.com](https://dylanbatt.com/)
- Email: [info@dylanbatt.com](mailto:info@dylanbatt.com)

If you have an app idea or need custom software development, feel free to get in touch.

---

## License

Copyright 2026 Dylan Batt. All rights reserved.
