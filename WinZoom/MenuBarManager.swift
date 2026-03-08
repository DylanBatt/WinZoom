//
//  MenuBarManager.swift
//  WinZoom
//
//  Owns the NSStatusItem (the menu bar icon) and manages two auxiliary
//  windows: the Settings panel and the About window.
//
//  Window lifecycle
//  ────────────────
//  Both windows use isReleasedWhenClosed = false so they can be re-shown
//  without being recreated. A close-notification observer nils the stored
//  reference when the user closes a window, preventing stale state.
//

import Cocoa
import SwiftUI
import os.log

/// Creates and manages the WinZoom menu bar icon, menu, and auxiliary windows.
final class MenuBarManager {

    // MARK: - Private properties

    /// The item in the system menu bar (icon + click action).
    private var statusItem: NSStatusItem?

    /// Retained reference to the Settings window (nil when closed).
    private var settingsWindow: NSWindow?

    /// Retained reference to the About window (nil when closed).
    private var aboutWindow: NSWindow?

    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "MenuBarManager")

    // MARK: - Setup

    /// Installs the menu bar icon and attaches the dropdown menu.
    /// Call once from AppDelegate.applicationDidFinishLaunching.
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Template images adapt automatically to dark/light menu bar tint.
            button.image = NSImage(
                systemSymbolName: "computermouse.fill",
                accessibilityDescription: "WinZoom"
            )
            button.image?.isTemplate = true
            button.toolTip = "WinZoom — Ctrl+Scroll to zoom"
        }

        statusItem?.menu = buildMenu()
        log.info("Menu bar item installed.")
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Non-interactive status label.
        let statusLabel = NSMenuItem(title: "Zoom: Active", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)

        menu.addItem(.separator())

        // About window.
        menu.addItem(makeItem(title: "About WinZoom",
                              action: #selector(openAbout),
                              key: ""))

        // Settings window (Cmd+, is the macOS convention for preferences).
        menu.addItem(makeItem(title: "Settings\u{2026}",
                              action: #selector(openSettings),
                              key: ","))

        menu.addItem(.separator())

        // Quit — no custom target so the action propagates through the
        // responder chain and reaches NSApplication.terminate(_:) directly.
        let quitItem = NSMenuItem(
            title: "Quit WinZoom",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    /// Convenience factory for a menu item targeted at self.
    private func makeItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Window actions

    /// Opens (or brings forward) the Settings window.
    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        settingsWindow = openWindow(view: SettingsView(), title: "WinZoom Settings")
    }

    /// Opens (or brings forward) the About window.
    @objc private func openAbout() {
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        aboutWindow = openWindow(view: AboutView(), title: "About WinZoom")
    }

    // MARK: - Generic window helper

    /// Creates, centres, and shows an NSWindow hosting the given SwiftUI view.
    /// Registers a close observer so the stored reference is nilled on close,
    /// preventing the window from being retained indefinitely.
    @discardableResult
    private func openWindow<V: View>(view: V, title: String) -> NSWindow {
        let hosting = NSHostingController(rootView: view)
        let window  = NSWindow(contentViewController: hosting)
        window.title              = title
        window.styleMask          = [.titled, .closable]
        window.isReleasedWhenClosed = false  // We manage the lifecycle manually.

        // Force SwiftUI to compute the ideal size before centering so that
        // center() has the correct window dimensions to work with.
        let idealSize = hosting.view.fittingSize
        if idealSize.width > 0 && idealSize.height > 0 {
            window.setContentSize(idealSize)
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Nil the stored reference when the user closes the window so the
        // next open call always creates a fresh, correctly-sized instance.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            if self.settingsWindow === window { self.settingsWindow = nil }
            if self.aboutWindow    === window { self.aboutWindow    = nil }
        }

        return window
    }
}
