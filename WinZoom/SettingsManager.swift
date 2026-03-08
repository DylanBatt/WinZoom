//
//  SettingsManager.swift
//  WinZoom
//
//  Single source of truth for all user-configurable preferences.
//  Settings are persisted via UserDefaults and published so SwiftUI views
//  (and ZoomEngine) can react to changes immediately.
//
//  Stored keys
//  ───────────
//  modifierKey   Int     0=Control  1=Command  2=Option
//  zoomSpeed     Double  1.0 (slow) … 10.0 (fast)
//  invertScroll  Bool    true = invert the zoom direction
//  launchAtLogin Bool    true = register as a login item
//

import Foundation
import Combine
import os.log

/// Observable settings store — one shared instance for the whole app.
final class SettingsManager: ObservableObject {

    // MARK: - Shared instance

    static let shared = SettingsManager()

    // MARK: - Published preferences

    /// Which modifier key triggers zoom (0 = Control, 1 = Command, 2 = Option).
    @Published var modifierKey: Int {
        didSet {
            // Clamp to the valid range before persisting.
            let clamped = modifierKey.clamped(to: 0...2)
            if clamped != modifierKey { modifierKey = clamped; return }
            UserDefaults.standard.set(modifierKey, forKey: Keys.modifierKey)
        }
    }

    /// Zoom speed multiplier (1 = slowest, 10 = fastest).
    @Published var zoomSpeed: Double {
        didSet {
            let clamped = zoomSpeed.clamped(to: 1.0...10.0)
            if clamped != zoomSpeed { zoomSpeed = clamped; return }
            UserDefaults.standard.set(zoomSpeed, forKey: Keys.zoomSpeed)
        }
    }

    /// When true, scrolling down zooms in and scrolling up zooms out.
    @Published var invertScroll: Bool {
        didSet { UserDefaults.standard.set(invertScroll, forKey: Keys.invertScroll) }
    }

    /// When true, WinZoom is registered as a login item via SMAppService.
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LoginItemManager.shared.setEnabled(launchAtLogin)
        }
    }

    // MARK: - UserDefaults keys (centralised to avoid typos)

    private enum Keys {
        static let modifierKey   = "modifierKey"
        static let zoomSpeed     = "zoomSpeed"
        static let invertScroll  = "invertScroll"
        static let launchAtLogin = "launchAtLogin"
    }

    // MARK: - Init

    private init() {
        // Register factory defaults so first-run values are sensible.
        UserDefaults.standard.register(defaults: [
            Keys.modifierKey:   0,
            Keys.zoomSpeed:     5.0,
            Keys.invertScroll:  false,
            Keys.launchAtLogin: false
        ])

        // Read persisted values, clamping to valid ranges for safety.
        modifierKey  = UserDefaults.standard.integer(forKey: Keys.modifierKey).clamped(to: 0...2)
        zoomSpeed    = UserDefaults.standard.double(forKey: Keys.zoomSpeed).clamped(to: 1.0...10.0)
        invertScroll = UserDefaults.standard.bool(forKey: Keys.invertScroll)
        launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
    }
}

// MARK: - Comparable clamping helpers

private extension Comparable {
    /// Returns the value clamped to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
