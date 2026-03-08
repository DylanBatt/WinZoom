//
//  LoginItemManager.swift
//  WinZoom
//
//  Registers or unregisters WinZoom as a login item using the modern
//  SMAppService API (macOS 13+). Any registration failure is surfaced
//  through the published `registrationError` property so the UI can
//  display an appropriate message to the user.
//

import Foundation
import ServiceManagement
import os.log

/// Manages the "Launch at Login" login-item registration for WinZoom.
final class LoginItemManager: ObservableObject {

    // MARK: - Shared instance

    static let shared = LoginItemManager()

    // MARK: - Published state

    /// Set when a registration or unregistration attempt fails.
    @Published private(set) var registrationError: String?

    // MARK: - Private properties

    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "LoginItemManager")

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Returns `true` if WinZoom is currently registered as a login item.
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers (enabled = true) or unregisters (enabled = false) the app
    /// as a login item. Updates `registrationError` on failure.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                log.info("Login item registered.")
            } else {
                try SMAppService.mainApp.unregister()
                log.info("Login item unregistered.")
            }
            // Clear any previous error on success.
            registrationError = nil
        } catch {
            let message = enabled
                ? "Could not enable launch at login: \(error.localizedDescription)"
                : "Could not disable launch at login: \(error.localizedDescription)"
            log.error("\(message)")
            registrationError = message
        }
    }
}
