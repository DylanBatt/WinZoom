//
//  PermissionsView.swift
//  WinZoom
//
//  Displays the current Accessibility permission status and provides a
//  button to open the system permission prompt. Embedded at the top of
//  SettingsView so the user always sees whether the engine is active.
//
//  The view polls AXIsProcessTrusted() on a 2-second timer while it is
//  on screen so the badge updates immediately after the user grants
//  permission in System Settings — without requiring an app relaunch.
//

import SwiftUI
import ApplicationServices
import Combine

struct PermissionsView: View {

    // MARK: - State

    /// Current Accessibility trust state; updated by the timer.
    @State private var isTrusted: Bool = AXIsProcessTrusted()

    /// Retained timer subscription — cancelled in onDisappear to prevent leaks.
    @State private var timerCancellable: AnyCancellable?

    // MARK: - Body

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                // Status icon changes colour based on permission state.
                Image(systemName: isTrusted
                      ? "checkmark.shield.fill"
                      : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(isTrusted ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Access")
                        .font(.headline)
                    Text(isTrusted
                         ? "Granted — WinZoom can intercept scroll events."
                         : "Required to intercept scroll events.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Only show the button when permission is missing.
                if !isTrusted {
                    Button("Grant Access") {
                        requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(4)
        }
        .onAppear {
            isTrusted = AXIsProcessTrusted()
            startPolling()
        }
        .onDisappear {
            // Always cancel the timer when the view leaves the screen to
            // prevent a retained closure from continuing to fire.
            stopPolling()
        }
    }

    // MARK: - Helpers

    /// Starts a repeating 2-second timer that rechecks the permission state.
    private func startPolling() {
        timerCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let nowTrusted = AXIsProcessTrusted()
                guard nowTrusted != isTrusted else { return }
                isTrusted = nowTrusted
                // Start (or stop) the zoom engine in response to the change.
                if nowTrusted {
                    ZoomEngine.shared.start()
                } else {
                    ZoomEngine.shared.stop()
                }
            }
    }

    /// Cancels the polling timer.
    private func stopPolling() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    /// Shows the system Accessibility permission prompt for this app.
    /// Uses takeUnretainedValue() because kAXTrustedCheckOptionPrompt is a
    /// framework constant — not a +1 CF transfer — so we must not over-retain.
    private func requestAccessibilityPermission() {
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(opts)
    }
}
