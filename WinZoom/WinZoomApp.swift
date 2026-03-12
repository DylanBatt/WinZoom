//
//  WinZoomApp.swift
//  WinZoom
//
//  App entry point. WinZoom is a menu bar-only utility (LSUIElement = YES
//  in Info.plist), so it intentionally has no Dock icon and no main window.
//
//  Architecture overview
//  ─────────────────────
//  • WinZoomApp   – @main entry point; declares the Settings scene.
//  • AppDelegate  – NSApplicationDelegate; wires up MenuBarManager and
//                   ZoomEngine at launch and tears them down on quit.
//  • MenuBarManager – Owns the NSStatusItem and auxiliary windows.
//  • ZoomEngine   – Global scroll-event monitor; synthesises zoom keystrokes.
//  • SettingsManager – Persists user preferences in UserDefaults.
//  • LoginItemManager – Registers / unregisters the SMAppService login item.
//
//  Why Settings scene instead of a custom window?
//  ───────────────────────────────────────────────
//  SwiftUI's `Settings` scene automatically enforces a single-instance
//  window, remembers its on-screen position across launches, and wires up
//  the standard Cmd+, keyboard shortcut. Because WinZoom is an LSUIElement
//  app (no visible menu bar), the shortcut is unused, but the single-instance
//  and position-memory behaviour are still desirable — hence using the
//  Settings scene instead of a plain WindowGroup.
//

import SwiftUI

/// The top-level SwiftUI `App` struct — serves as the @main entry point.
/// SwiftUI instantiates this once and keeps it alive for the app's lifetime.
@main
struct WinZoomApp: App {

    // Bridge UIKit-style delegate callbacks (applicationDidFinishLaunching,
    // applicationWillTerminate, etc.) into SwiftUI's App lifecycle.
    // AppDelegate is responsible for all imperative setup that SwiftUI's
    // declarative scene model cannot express (status items, event monitors…).
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The Settings scene provides proper window lifecycle management
        // (single instance, remembers position) for the preferences panel.
        // It is opened programmatically by MenuBarManager via the
        // "Settings…" menu item rather than through the keyboard shortcut,
        // because LSUIElement apps do not show a standard macOS menu bar.
        Settings {
            SettingsView()
        }
    }
}
