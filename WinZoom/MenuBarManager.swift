//
//  MenuBarManager.swift
//  WinZoom
//
//  Owns the NSStatusItem (the menu bar icon) and manages two auxiliary
//  windows: the Settings panel and the About window.
//
//  Window lifecycle
//  ────────────────
//  Both windows use `isReleasedWhenClosed = false` so Swift keeps them
//  alive after the user clicks the close button.  A WillClose notification
//  observer nils the stored reference at that point, so the *next* call to
//  openSettings / openAbout always creates a fresh, correctly-sized window
//  rather than re-showing a stale one with the wrong size.
//
//  Why not use the SwiftUI WindowGroup scene?
//  ──────────────────────────────────────────
//  WinZoom is an LSUIElement app — it has no dock icon and no system menu
//  bar. SwiftUI WindowGroup (and OpenWindowAction) require a running main
//  menu to function correctly, so we manage windows imperatively with
//  NSWindow + NSHostingController instead.
//

import Cocoa
import SwiftUI
import os.log

/// Creates and manages the WinZoom menu bar icon, menu, and auxiliary windows.
///
/// Conforms to `NSMenuDelegate` so the status label in the dropdown menu is
/// refreshed every time the user opens it, reflecting the real engine state.
///
/// Owned by `AppDelegate` as a stored property, so this object lives for the
/// entire app lifetime.
final class MenuBarManager: NSObject, NSMenuDelegate {

    // MARK: - Private properties

    /// The item shown in the system menu bar (icon + dropdown on click).
    /// Must be stored; NSStatusBar removes the item from the bar if the
    /// NSStatusItem is deallocated.
    private var statusItem: NSStatusItem?

    /// Weak reference to the status label menu item so it can be updated
    /// each time the menu opens without rebuilding the whole menu.
    private weak var statusLabelItem: NSMenuItem?

    /// Retained reference to the open Settings window.
    /// Set to nil via the WillClose observer when the user closes it, so
    /// that the next "Settings…" click always opens a fresh window.
    private var settingsWindow: NSWindow?

    /// Retained reference to the open About window (same lifecycle as above).
    private var aboutWindow: NSWindow?

    /// Structured log for menu bar events (visible in Console.app).
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "MenuBarManager")

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - Setup

    /// Installs the status item in the system menu bar and attaches the
    /// dropdown menu.  Call exactly once from AppDelegate.applicationDidFinishLaunching.
    func setup() {
        // squareLength gives a fixed-width item that matches other icon-only
        // status items in the menu bar.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // SF Symbol "computermouse.fill" is used as a template image so
            // it automatically adapts its colour to the current menu bar tint
            // (dark/light/coloured) — no manual tinting needed.
            button.image = NSImage(
                systemSymbolName: "computermouse.fill",
                accessibilityDescription: "WinZoom"
            )
            // isTemplate = true tells AppKit to render the image as a mask,
            // honouring the menu bar's effective appearance automatically.
            button.image?.isTemplate = true
            // Tool-tip visible when the user hovers over the icon.
            button.toolTip = "WinZoom — Ctrl+Scroll to zoom"
        }

        statusItem?.menu = buildMenu()
        log.info("Menu bar item installed.")
    }

    // MARK: - Menu construction

    /// Builds and returns the dropdown NSMenu shown when the icon is clicked.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Non-interactive status label at the top so users immediately see
        // that the zoom engine is active without opening Settings.
        let statusLabel = NSMenuItem(title: "Zoom: Active", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false  // Greyed out — purely informational.
        menu.addItem(statusLabel)
        statusLabelItem = statusLabel  // Keep a weak reference for updates.

        menu.addItem(.separator())

        // Opens the About window (developer credit, links, etc.).
        menu.addItem(makeItem(title: "About WinZoom",
                              action: #selector(openAbout),
                              key: ""))

        // Opens the Settings / Preferences window.
        // Cmd+, is the standard macOS convention for the Preferences item;
        // it won't be reachable via keyboard in an LSUIElement app, but
        // including it follows the convention for discoverability.
        menu.addItem(makeItem(title: "Settings\u{2026}",   // "Settings…"
                              action: #selector(openSettings),
                              key: ","))

        menu.addItem(.separator())

        // Standard Quit item. No explicit target is set, so the action
        // propagates through the responder chain and is handled by
        // NSApplication.terminate(_:) automatically.
        let quitItem = NSMenuItem(
            title: "Quit WinZoom",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        // Set the menu delegate to self for live updates.
        menu.delegate = self

        return menu
    }

    /// Convenience factory that creates an NSMenuItem targeted at `self`.
    ///
    /// Setting `target = self` is required for items whose actions are
    /// defined on this class; without it AppKit cannot find the responder.
    private func makeItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Activation helper

    /// Brings the app to the foreground using the appropriate API for the
    /// running OS version.
    ///
    /// `activate(ignoringOtherApps:)` was deprecated in macOS 14 Sonoma.
    /// The replacement is the parameter-less `NSApp.activate()`, available
    /// from macOS 14 onwards.
    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Window actions

    /// Opens the Settings window, or brings it to the front if already open.
    @objc private func openSettings() {
        // If the window already exists and is visible, just raise it rather
        // than creating a duplicate.
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }
        // Create a new window hosting SettingsView and store the reference.
        settingsWindow = openWindow(view: SettingsView(), title: "WinZoom Settings")
    }

    /// Opens the About window, or brings it to the front if already open.
    @objc private func openAbout() {
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }
        aboutWindow = openWindow(view: AboutView(), title: "About WinZoom")
    }

    // MARK: - Generic window helper

    /// Creates, sizes, centres, and shows an `NSWindow` that hosts the given
    /// SwiftUI view, then returns it to the caller for storage.
    ///
    /// The window is deliberately *not* released on close
    /// (`isReleasedWhenClosed = false`) so Swift's ARC controls its lifetime.
    /// A WillClose observer nils the caller's stored reference so that the
    /// next open call always produces a fresh instance at the correct size.
    ///
    /// - Parameters:
    ///   - view:  The SwiftUI root view to embed in the window.
    ///   - title: The string shown in the window's title bar.
    /// - Returns: The newly created and visible `NSWindow`.
    @discardableResult
    private func openWindow<V: View>(view: V, title: String) -> NSWindow {
        // NSHostingController bridges a SwiftUI view hierarchy into an
        // NSViewController / NSView that AppKit can host in an NSWindow.
        let hosting = NSHostingController(rootView: view)
        let window  = NSWindow(contentViewController: hosting)

        window.title     = title
        // .titled + .closable: standard chrome with title bar and close button,
        // but no minimise or zoom buttons (not appropriate for utility panels).
        window.styleMask = [.titled, .closable]
        // Prevent AppKit from deallocating the window when the user closes it.
        // We manage lifetime manually via the stored reference + close observer.
        window.isReleasedWhenClosed = false

        // Ask SwiftUI for the view's ideal (fitting) size *before* centering,
        // so that center() uses the correct dimensions rather than a default
        // 480×270 frame.
        let idealSize = hosting.view.fittingSize
        if idealSize.width > 0 && idealSize.height > 0 {
            window.setContentSize(idealSize)
        }

        // Place the window in the centre of the main display.
        window.center()
        window.makeKeyAndOrderFront(nil)
        // Bring the app to the foreground so the window is immediately usable.
        activateApp()

        // Register a one-shot WillClose observer.  When the user closes this
        // window, nil out the stored strong reference so a fresh window is
        // created next time.  Using [weak self] and [weak window] prevents a
        // retain cycle between the closure, the observation token, and the
        // objects it captures.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            // Determine which stored reference to nil based on identity (===).
            if self.settingsWindow === window { self.settingsWindow = nil }
            if self.aboutWindow    === window { self.aboutWindow    = nil }
        }

        return window
    }

    // MARK: - NSMenuDelegate

    /// Called just before the menu is displayed to the user.
    /// Updates the status label so it always reflects the real engine state
    /// at the moment the menu opens — no separate timer or observer needed.
    func menuWillOpen(_ menu: NSMenu) {
        let isActive = ZoomEngine.shared.isRunning
        statusLabelItem?.title = isActive ? "Zoom: Active" : "Zoom: Inactive"
    }
}
