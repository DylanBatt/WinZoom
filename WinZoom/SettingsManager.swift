//
//  SettingsManager.swift
//  WinZoom
//
//  Single source of truth for all user-configurable preferences.
//  Settings are persisted via UserDefaults and published so SwiftUI views
//  (and ZoomEngine) can react to changes immediately without polling.
//
//  Stored UserDefaults keys
//  ────────────────────────
//  modifierKey   Int (raw value of ModifierKey enum)
//                0 = Control (^),  1 = Command (⌘),  2 = Option (⌥)
//  zoomSpeed     Double  1.0 (slow) … 10.0 (fast)
//  invertScroll  Bool    true = invert the zoom direction
//  launchAtLogin Bool    true = register the app as an SMAppService login item
//
//  Why UserDefaults and not a plist / JSON file?
//  ─────────────────────────────────────────────
//  For a small set of scalar preferences, UserDefaults is the idiomatic
//  macOS storage mechanism.  It is thread-safe, backed by a sandboxed
//  container, and requires zero boilerplate for read/write.
//

import Cocoa
import Foundation
import os.log

// MARK: - ModifierKey

/// The modifier key that must be held while scrolling to trigger zoom.
///
/// Raw `Int` values match the integers previously stored in UserDefaults
/// (0/1/2), so existing user preferences are preserved without migration.
enum ModifierKey: Int, CaseIterable {
    case control = 0   // ⌃ Control — the default; matches Windows Ctrl+Scroll
    case command = 1   // ⌘ Command
    case option  = 2   // ⌥ Option / Alt

    /// The corresponding `NSEvent.ModifierFlags` value used by `ZoomEngine`.
    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .command: return .command
        case .option:  return .option
        }
    }
}

// MARK: - SettingsManager

/// Observable settings store shared across the entire application.
///
/// Conforms to `ObservableObject` so SwiftUI views can subscribe to changes
/// with `@ObservedObject`.  All writes go through `@Published` property
/// observers which persist the new value to `UserDefaults` immediately.
///
/// Usage:
/// ```swift
/// let speed = SettingsManager.shared.zoomSpeed
/// SettingsManager.shared.zoomSpeed = 7.0
/// ```
final class SettingsManager: ObservableObject {

    // MARK: - Shared instance

    /// Application-wide singleton — use this instead of creating new instances.
    static let shared = SettingsManager()

    // MARK: - Published preferences

    /// Which modifier key must be held while scrolling to trigger zoom.
    ///
    /// Stored in UserDefaults as the enum's raw `Int` value so existing
    /// preferences survive the change from a plain `Int` to this typed enum.
    @Published var modifierKey: ModifierKey {
        didSet { UserDefaults.standard.set(modifierKey.rawValue, forKey: Keys.modifierKey) }
    }

    /// How quickly zoom steps fire relative to scroll speed.
    ///
    /// Maps to the threshold formula in ZoomEngine:
    ///   threshold = max(2.0, 22.0 − (zoomSpeed × 2.0))
    ///
    /// Valid range: 1.0 (slow — requires more scrolling per step) to
    ///              10.0 (fast — fires almost every scroll frame).
    @Published var zoomSpeed: Double {
        didSet {
            let clamped = zoomSpeed.clamped(to: 1.0...10.0)
            if clamped != zoomSpeed { zoomSpeed = clamped; return }
            UserDefaults.standard.set(zoomSpeed, forKey: Keys.zoomSpeed)
        }
    }

    /// When `true`, the scroll direction is reversed:
    /// scrolling down zooms in and scrolling up zooms out.
    @Published var invertScroll: Bool {
        didSet { UserDefaults.standard.set(invertScroll, forKey: Keys.invertScroll) }
    }

    /// When `true`, WinZoom is registered as a login item via `SMAppService`
    /// so it launches automatically when the user logs in.
    ///
    /// Changing this property automatically calls
    /// `LoginItemManager.shared.setEnabled(_:)` to update the system
    /// registration in addition to persisting the preference.
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            // Keep the SMAppService registration in sync with the preference.
            LoginItemManager.shared.setEnabled(launchAtLogin)
        }
    }

    // MARK: - UserDefaults keys

    /// Centralised string constants for UserDefaults keys.
    ///
    /// Using an enum (rather than inline string literals) means a typo in a
    /// key name is caught at compile time, not silently lost at runtime.
    private enum Keys {
        static let modifierKey   = "modifierKey"
        static let zoomSpeed     = "zoomSpeed"
        static let invertScroll  = "invertScroll"
        static let launchAtLogin = "launchAtLogin"
    }

    // MARK: - Init

    /// Private to enforce the singleton pattern.
    private init() {
        // register(defaults:) sets *factory* defaults — values that are
        // returned only when the key has never been explicitly written.
        // Explicitly written values always take precedence, so calling
        // register(defaults:) on every launch is safe and idempotent.
        UserDefaults.standard.register(defaults: [
            Keys.modifierKey:   ModifierKey.control.rawValue,  // Control (^)
            Keys.zoomSpeed:     5.0,    // Moderate speed
            Keys.invertScroll:  false,  // Natural scroll direction
            Keys.launchAtLogin: false   // Don't auto-launch until the user opts in
        ])

        // Read persisted values.  For modifierKey, fall back to .control if the
        // stored integer doesn't match a known case (e.g. from a future version).
        let rawModifier = UserDefaults.standard.integer(forKey: Keys.modifierKey)
        modifierKey   = ModifierKey(rawValue: rawModifier) ?? .control
        zoomSpeed     = UserDefaults.standard.double(forKey: Keys.zoomSpeed).clamped(to: 1.0...10.0)
        invertScroll  = UserDefaults.standard.bool(forKey: Keys.invertScroll)
        // Derive launchAtLogin from the actual SMAppService registration state
        // so the toggle reflects reality even if the user removed the login
        // item in System Settings → General → Login Items outside of the app.
        launchAtLogin = LoginItemManager.shared.isEnabled
    }
}

// MARK: - Comparable clamping helpers

private extension Comparable {
    /// Returns `self` clamped to the given closed range.
    ///
    /// Example:
    /// ```swift
    /// (-3).clamped(to: 0...10)  // → 0
    /// 15.clamped(to: 0...10)    // → 10
    /// 5.clamped(to: 0...10)     // → 5
    /// ```
    func clamped(to range: ClosedRange<Self>) -> Self {
        // Swift's built-in min/max functions on Comparable do the job
        // without requiring the value to conform to a numeric protocol.
        min(max(self, range.lowerBound), range.upperBound)
    }
}
