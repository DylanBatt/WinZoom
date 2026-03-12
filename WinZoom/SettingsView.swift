//
//  SettingsView.swift
//  WinZoom
//
//  The main preferences panel, opened from the menu bar "Settings…" item.
//
//  Layout approach
//  ───────────────
//  VStack + GroupBox is used instead of SwiftUI's Form so the window
//  auto-sizes precisely to its content (fixedSize()) without introducing
//  a scrollable container — the panel is intentionally small and fixed.
//
//  Sections
//  ────────
//  1. PermissionsView — always-visible engine-status banner at the top.
//  2. "Zoom" GroupBox — trigger key picker, speed slider, invert toggle.
//  3. "General" GroupBox — launch-at-login toggle + error display.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Dependencies

    // @ObservedObject is used (not @StateObject) because SettingsManager is a
    // pre-existing singleton that this view does not own.
    //
    // @StateObject would create a *new* instance on first render, which would
    // shadow the real singleton and cause settings changes to be lost.
    // @ObservedObject correctly subscribes to the existing shared instance.
    @ObservedObject private var settings = SettingsManager.shared

    /// Human-readable display labels keyed by `ModifierKey` case.
    private func label(for key: ModifierKey) -> String {
        switch key {
        case .control: return "Control (^)"
        case .command: return "Command (⌘)"
        case .option:  return "Option (⌥)"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Engine status banner ───────────────────────────────────────
            // PermissionsView polls ZoomEngine.isRunning on a 2-second timer
            // and updates the badge automatically.  Placed at the top so the
            // user can always see whether the engine is active.
            PermissionsView()

            // ── Zoom settings ─────────────────────────────────────────────
            GroupBox("Zoom") {
                VStack(alignment: .leading, spacing: 12) {

                    // Trigger key — segmented control so all three options are
                    // visible at once, making the choice immediately obvious.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trigger key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $settings.modifierKey) {
                            // Iterate over all enum cases so the picker stays
                            // in sync automatically if new keys are ever added.
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(label(for: key)).tag(key)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()  // The GroupBox title provides the label context.
                    }

                    Divider()

                    // Zoom speed — a discrete 1–10 slider.  The step: 1 argument
                    // snaps to integer values so the speedLabel always maps cleanly.
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Zoom speed")
                                .font(.subheadline)
                            Spacer()
                            // monospacedDigit prevents the label from shifting
                            // horizontally as the single character changes width.
                            Text(speedLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.zoomSpeed, in: 1...10, step: 1)
                            .tint(.accentColor)
                    }

                    Divider()

                    // Invert scroll direction — reverses the delta sign in ZoomEngine
                    // so scrolling down zooms in (matches some trackpad preferences).
                    Toggle("Invert scroll direction", isOn: $settings.invertScroll)
                        .font(.subheadline)
                }
                .padding(4)  // Small inset so content doesn't touch the GroupBox border.
            }

            // ── General settings ──────────────────────────────────────────
            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    // Launch at login — writes to SettingsManager which in turn
                    // calls LoginItemManager.shared.setEnabled(_:).
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .font(.subheadline)

                    // If the item is registered but the user disabled it in
                    // System Settings → General → Login Items, guide them there.
                    if let hint = LoginItemManager.shared.approvalRequiredHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Show any SMAppService registration error inline so the user
                    // can act on it without hunting through system logs.
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
        // Fixed width of 380 pt; height is determined by fixedSize() below.
        .frame(width: 380)
        // fixedSize() tells SwiftUI to size the window to the view's ideal
        // (fitting) size rather than stretching it to fill available space.
        // This is what allows MenuBarManager to read fittingSize accurately.
        .fixedSize()
    }

    // MARK: - Helpers

    /// Returns a human-readable label for the current zoom speed value.
    ///
    /// Used next to the slider to give the raw number a qualitative meaning.
    private var speedLabel: String {
        switch Int(settings.zoomSpeed) {
        case 1...3:  return "Slow"
        case 4...6:  return "Normal"
        case 7...9:  return "Fast"
        case 10:     return "Turbo"
        default:     return "Normal"  // Fallback — should not be reached given clamping.
        }
    }
}

#Preview {
    SettingsView()
}
