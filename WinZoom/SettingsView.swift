//
//  SettingsView.swift
//  WinZoom
//
//  The main preferences panel, opened from the menu bar icon.
//  Laid out with VStack + GroupBox (not Form) so the window auto-sizes
//  to content without a scrollable container.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Dependencies

    /// @ObservedObject is correct here because SettingsManager is a pre-existing
    /// singleton — we observe it, we don't own it (@StateObject would recreate it).
    @ObservedObject private var settings = SettingsManager.shared

    /// Labels shown in the modifier-key picker.
    private let modifierOptions = ["Control (^)", "Command (cmd)", "Option (opt)"]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Accessibility permission banner — always visible at the top.
            PermissionsView()

            // ── Zoom settings ─────────────────────────────────────────────
            GroupBox("Zoom") {
                VStack(alignment: .leading, spacing: 12) {

                    // Trigger key picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trigger key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $settings.modifierKey) {
                            ForEach(modifierOptions.indices, id: \.self) { index in
                                Text(modifierOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider()

                    // Zoom speed slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Zoom speed")
                                .font(.subheadline)
                            Spacer()
                            Text(speedLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.zoomSpeed, in: 1...10, step: 1)
                            .tint(.accentColor)
                    }

                    Divider()

                    // Invert direction toggle
                    Toggle("Invert scroll direction", isOn: $settings.invertScroll)
                        .font(.subheadline)
                }
                .padding(4)
            }

            // ── General settings ──────────────────────────────────────────
            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .font(.subheadline)

                    // Show any login-item registration errors inline.
                    if let error = LoginItemManager.shared.registrationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(4)
            }
        }
        .padding()
        .frame(width: 380)
        .fixedSize()
    }

    // MARK: - Helpers

    /// Human-readable label for the current zoom speed value.
    private var speedLabel: String {
        switch Int(settings.zoomSpeed) {
        case 1...3:  return "Slow"
        case 4...6:  return "Normal"
        case 7...9:  return "Fast"
        case 10:     return "Turbo"
        default:     return "Normal"
        }
    }
}

#Preview {
    SettingsView()
}
