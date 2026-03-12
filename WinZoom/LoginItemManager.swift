//
//  LoginItemManager.swift
//  WinZoom
//
//  Registers or unregisters WinZoom as a login item using the modern
//  SMAppService API (macOS 13+).  Any registration failure is surfaced
//  through the published `registrationError` property so SettingsView
//  can display an inline error message to the user.
//
//  SMAppService overview
//  ─────────────────────
//  Introduced in macOS 13 (Ventura), SMAppService replaces the deprecated
//  SMLoginItemRegisterURL and LSSharedFileList APIs.  It manages login items
//  in the "Allow in the Background" section of System Settings → General →
//  Login Items.  The user can always override the setting there.
//
//  `SMAppService.mainApp` refers to the running application itself — no
//  separate helper bundle is required for a simple "launch at login" feature.
//  Call `.register()` to enable and `.unregister()` to disable.
//

import Foundation
import ServiceManagement  // SMAppService
import os.log

/// Manages the "Launch at Login" login-item registration for WinZoom.
///
/// Uses `SMAppService.mainApp` (macOS 13+) to register or unregister the
/// app as a login item.  The `registrationError` property is published so
/// SwiftUI views can observe and display errors without polling.
///
/// This is a singleton (`LoginItemManager.shared`) because the login-item
/// registration state is global — there should never be more than one
/// manager operating at a time.
final class LoginItemManager: ObservableObject {

    // MARK: - Shared instance

    /// The application-wide singleton instance.
    static let shared = LoginItemManager()

    // MARK: - Published state

    /// Set to a localised error message when a register / unregister call
    /// fails; cleared back to nil on the next successful call.
    ///
    /// Observed by SettingsView to display an inline error banner.
    @Published private(set) var registrationError: String?

    // MARK: - Private properties

    /// Structured log — messages appear in Console.app under the WinZoom
    /// subsystem and "LoginItemManager" category.
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "LoginItemManager")

    // MARK: - Init

    /// Private to enforce the singleton pattern.
    private init() {}

    // MARK: - Public API

    /// Returns `true` if WinZoom is registered as a login item (including
    /// the case where it is registered but requires the user's approval in
    /// System Settings → General → Login Items).
    ///
    /// Both `.enabled` and `.requiresApproval` mean the entry exists in the
    /// login items database; only `.notRegistered` and `.notFound` mean it
    /// is absent.  Treating `.requiresApproval` as `true` keeps the toggle
    /// switched on so the user knows registration exists and can act on the
    /// "requires approval" hint shown separately.
    var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    /// Returns a human-readable hint when the login item requires the user's
    /// approval in System Settings, or `nil` when no hint is needed.
    var approvalRequiredHint: String? {
        guard SMAppService.mainApp.status == .requiresApproval else { return nil }
        return "WinZoom is registered but has been disabled in System Settings → General → Login Items. Enable it there to launch at login."
    }

    /// Registers (`enabled = true`) or unregisters (`enabled = false`) the app
    /// as a login item via `SMAppService.mainApp`.
    ///
    /// On success, clears any previous `registrationError`.
    /// On failure, sets `registrationError` to a user-readable message and
    /// logs the underlying error for diagnostics.
    ///
    /// - Parameter enabled: Pass `true` to register, `false` to unregister.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                // Registers the app in the user's login items.  macOS may
                // show a notification the first time ("WinZoom was added to
                // Login Items").
                try SMAppService.mainApp.register()
                log.info("Login item registered.")
            } else {
                // Removes the app from the user's login items.
                try SMAppService.mainApp.unregister()
                log.info("Login item unregistered.")
            }
            // Clear any previous error so the UI stops showing it.
            registrationError = nil
        } catch {
            // Build a user-facing message that disambiguates between enable
            // and disable failures.
            let message = enabled
                ? "Could not enable launch at login: \(error.localizedDescription)"
                : "Could not disable launch at login: \(error.localizedDescription)"
            log.error("\(message)")
            // Publish the error so SettingsView can display it inline.
            registrationError = message
        }
    }
}
