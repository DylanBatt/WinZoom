//
//  PermissionsView.swift
//  WinZoom
//
//  Displays the current scroll-zoom engine status as a banner at the top of
//  SettingsView so the user can see at a glance whether WinZoom is working.
//
//  Polling approach
//  ────────────────
//  ZoomEngine.isRunning is a plain computed property (not @Published), so
//  this view cannot observe it reactively.  Instead a 2-second Timer fires
//  while the view is on screen and updates `isRunning` if the value has
//  changed.  This is intentionally lightweight: checks are infrequent and
//  the guard statement prevents unnecessary SwiftUI re-renders.
//
//  The timer is started in onAppear and cancelled in onDisappear to avoid
//  a timer leak when the Settings window is closed.
//

import SwiftUI
import Combine  // Timer.publish, AnyCancellable

struct PermissionsView: View {
    
    // MARK: - State
    
    /// Mirrors ZoomEngine.shared.isRunning; drives the badge icon and text.
    /// Initialised synchronously so the very first render reflects the true
    /// engine state without waiting for the first timer tick.
    @State private var isRunning: Bool = ZoomEngine.shared.isRunning
    
    /// Subscription token for the polling timer.
    ///
    /// Stored as `@State` so it is retained for the view's lifetime but
    /// not part of the view's identity (it doesn't affect rendering).
    /// Cancelling via `timerCancellable?.cancel()` stops the underlying
    /// Combine pipeline and releases the underlying timer resources.
    @State private var timerCancellable: AnyCancellable?
    
    // MARK: - Body
    
    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                
                // Badge icon — green shield when running, orange when not.
                // SF Symbols are used so the icon scales with Dynamic Type
                // and honours the system accent colour automatically.
                Image(systemName: isRunning
                      ? "checkmark.shield.fill"
                      : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(isRunning ? .green : .orange)
                
                // Status text — heading + one-line description.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scroll-Zoom Engine")
                        .font(.headline)
                    Text(isRunning
                         ? "Active — scroll with the modifier key to zoom."
                         : "Inactive — scroll monitoring could not be started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // "Retry" button is only shown when the engine is NOT running.
                // Tapping it attempts to re-start ZoomEngine (e.g. after the
                // user has granted Accessibility permission without relaunching).
                if !isRunning {
                    Button("Retry") {
                        // Attempt to start the engine with the current
                        // Accessibility permission state.
                        ZoomEngine.shared.start()
                        // Update state immediately so the UI reflects the
                        // result of the retry without waiting for the next
                        // timer tick.
                        isRunning = ZoomEngine.shared.isRunning
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(4)
        }
        .onAppear {
            // Re-check immediately in case the state changed while the view
            // was off screen (e.g. the user granted permission and re-opened
            // the Settings window).
            isRunning = ZoomEngine.shared.isRunning
            startPolling()
        }
        .onDisappear {
            // Cancel the timer to prevent it firing after the view is gone,
            // which would reference a deallocated view hierarchy.
            stopPolling()
        }
    }
    
    // MARK: - Helpers
    
    /// Starts a repeating 2-second Combine timer that re-checks the engine
    /// state.  If Accessibility permission was granted while the view was on
    /// screen, the timer also starts the engine — no relaunch required.
    private func startPolling() {
        // Timer.publish creates a Combine publisher that fires on the main
        // run loop every `every` seconds.  autoconnect() starts it immediately
        // without needing an explicit `.connect()` call.
        timerCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { @MainActor _ in
                // If the engine isn't running yet, try to start it — this
                // handles the case where the user grants Accessibility
                // permission in System Settings without relaunching the app.
                if !ZoomEngine.shared.isRunning {
                    ZoomEngine.shared.start()
                }
                let nowRunning = ZoomEngine.shared.isRunning
                // Guard prevents a pointless SwiftUI diff on every tick.
                guard nowRunning != isRunning else { return }
                isRunning = nowRunning
            }
    }
    
    /// Cancels the polling timer and releases the Combine subscription.
    private func stopPolling() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
