//
//  AppDelegate.swift
//  WinZoom
//
//  NSApplicationDelegate that wires together the three core components on
//  launch: menu bar UI, zoom engine, and accessibility permission check.
//  Also cleanly tears down the zoom engine when the app quits.
//

import Cocoa
import ApplicationServices
import os.log

/// Application delegate — the first point of execution after @main.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Private properties

    /// Manages the NSStatusItem (menu bar icon + dropdown menu).
    private let menuBarManager = MenuBarManager()

    /// Logger for lifecycle events.
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "AppDelegate")

    // MARK: - NSApplicationDelegate

    /// Called once the app is fully launched and the run loop is running.
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("WinZoom launched.")

        // Install the menu bar icon and menu before anything else.
        menuBarManager.setup()

        if AXIsProcessTrusted() {
            // Accessibility already granted — start listening immediately.
            ZoomEngine.shared.start()
        }
        // If not yet trusted, PermissionsView will guide the user to
        // System Settings and poll until permission is granted.
    }

    /// Called just before the app terminates — stop the event monitor cleanly.
    func applicationWillTerminate(_ notification: Notification) {
        ZoomEngine.shared.stop()
        log.info("WinZoom terminated.")
    }
}
