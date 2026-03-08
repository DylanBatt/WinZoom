//
//  WinZoomApp.swift
//  WinZoom
//
//  App entry point. WinZoom is a menu bar-only utility (LSUIElement = YES)
//  so it has no Dock icon and no main application window.
//
//  AppDelegate handles all setup; the Settings scene provides the standard
//  macOS preferences window lifecycle and is opened programmatically by
//  MenuBarManager rather than through a keyboard shortcut (since LSUIElement
//  apps do not expose a standard menu bar to the user).
//

import SwiftUI

@main
struct WinZoomApp: App {

    /// Bridges to AppDelegate for NSApplication lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The Settings scene provides proper window lifecycle management
        // (single instance, remembers position) for the preferences panel.
        // It is opened by MenuBarManager via the "Settings…" menu item.
        Settings {
            SettingsView()
        }
    }
}
