//
//  AppDelegate.swift
//  WinZoom
//
//  NSApplicationDelegate that wires together the three core components on
//  launch: menu bar UI, zoom engine, and accessibility permission check.
//  Also cleanly tears down the zoom engine when the app quits.
//
//  Accessibility permission flow
//  ─────────────────────────────
//  macOS requires the "Accessibility" permission (under System Settings →
//  Privacy & Security) before an app can monitor global keyboard / mouse
//  events. WinZoom checks this at launch:
//    1. Already granted  → start ZoomEngine immediately.
//    2. Not yet granted  → call AXIsProcessTrustedWithOptions to display the
//       system prompt, then let PermissionsView poll until the user grants it.
//

import Cocoa
import ApplicationServices  // AXIsProcessTrusted, kAXTrustedCheckOptionPrompt
import os.log

/// Application delegate — the first point of execution after @main.
///
/// Responsibilities:
/// - Install the menu bar status item via `MenuBarManager`.
/// - Start `ZoomEngine` once Accessibility permission is confirmed.
/// - Prompt for Accessibility permission when it hasn't been granted yet.
/// - Stop `ZoomEngine` cleanly when the app is about to quit.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Private properties

    /// Manages the NSStatusItem (menu bar icon + dropdown menu).
    /// Declared as a stored property so it is retained for the entire app
    /// lifetime — NSStatusItem is removed from the menu bar if deallocated.
    private let menuBarManager = MenuBarManager()

    /// Structured log for app-lifecycle events (visible in Console.app).
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "AppDelegate")

    // MARK: - NSApplicationDelegate

    /// Called once the NSApplication run loop has started and the app is
    /// fully operational.  All initialisation lives here rather than in init()
    /// so that the run loop is available (needed for event monitors, timers…).
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("WinZoom launched.")

        // Install the menu bar icon and build the dropdown menu before
        // anything else so the UI appears as quickly as possible.
        menuBarManager.setup()

        if AXIsProcessTrusted() {
            // Accessibility is already authorised — start the scroll-event
            // monitor straight away. No UI prompt is needed.
            ZoomEngine.shared.start()
        } else {
            // Accessibility has not been granted yet.  Pass the
            // kAXTrustedCheckOptionPrompt option so macOS automatically shows
            // the "WinZoom would like to control this computer" alert and
            // opens System Settings → Privacy & Security → Accessibility.
            //
            // Memory note: takeUnretainedValue() is used (not takeRetainedValue())
            // because kAXTrustedCheckOptionPrompt is a framework-owned constant
            // — it is NOT a +1 transfer.  Using takeRetainedValue() here would
            // over-release the object and cause a crash.
            let opts: NSDictionary = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ]
            // _ = explicitly discards the Bool return value; we don't need
            // the result here because PermissionsView polls for the change.
            _ = AXIsProcessTrustedWithOptions(opts)

            // After this point, PermissionsView (embedded in SettingsView)
            // polls AXIsProcessTrusted() on a 2-second timer and calls
            // ZoomEngine.shared.start() once permission is granted.
        }
    }

    /// Called just before the process exits.  Removes the global event
    /// monitor so no further scroll callbacks fire during teardown.
    func applicationWillTerminate(_ notification: Notification) {
        ZoomEngine.shared.stop()
        log.info("WinZoom terminated.")
    }
}
