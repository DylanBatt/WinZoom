//
//  ZoomEngine.swift
//  WinZoom
//
//  Intercepts scroll-wheel events system-wide and converts them into
//  Cmd+= (zoom in) or Cmd+- (zoom out) keystrokes sent to the focused
//  application — mirroring the Windows Ctrl+Scroll zoom behaviour.
//
//  Implementation notes
//  ────────────────────
//  • Uses NSEvent.addGlobalMonitorForEvents which is fully sandbox-compatible
//    and therefore accepted by the Mac App Store. The trade-off versus a
//    CGEventTap is that we cannot *consume* the original scroll event; in
//    apps that already handle Ctrl+Scroll natively (e.g. Chrome) users may
//    see a double-zoom step and should switch the trigger key to Option.
//  • Requires Accessibility permission, prompted via PermissionsView.
//  • All callbacks arrive on the main thread — safe to read @Published
//    properties from SettingsManager without additional synchronisation.
//

import Cocoa
import ApplicationServices
import os.log

/// Singleton responsible for monitoring scroll events and posting zoom
/// keystrokes to the currently-focused application.
final class ZoomEngine {

    // MARK: - Shared instance

    static let shared = ZoomEngine()

    // MARK: - Private state

    /// Opaque token returned by NSEvent's global monitor; nil when stopped.
    private var eventMonitor: Any?

    /// Accumulated scroll delta between zoom steps, reset on direction change.
    private var scrollAccumulator: Double = 0

    /// Logger for diagnostic messages (visible in Console.app at runtime).
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "ZoomEngine")

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Returns `true` while the event monitor is active.
    var isRunning: Bool { eventMonitor != nil }

    /// Starts monitoring global scroll events.
    /// Does nothing if the monitor is already running or if Accessibility
    /// permission has not been granted.
    func start() {
        guard eventMonitor == nil else { return }
        guard AXIsProcessTrusted() else {
            log.warning("Accessibility permission not granted — zoom engine not started.")
            return
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }

        if eventMonitor != nil {
            log.info("ZoomEngine started.")
        } else {
            log.error("addGlobalMonitorForEvents returned nil — check Accessibility permission.")
        }
    }

    /// Stops monitoring and resets the scroll accumulator.
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            scrollAccumulator = 0
            log.info("ZoomEngine stopped.")
        }
    }

    // MARK: - Event handling

    /// Processes a scroll-wheel event and fires zoom keystrokes when the
    /// configured modifier key is held.
    private func handleScrollEvent(_ event: NSEvent) {
        let settings = SettingsManager.shared

        // Build the required modifier flag from the user's preference.
        let requiredFlag: NSEvent.ModifierFlags
        switch settings.modifierKey {
        case 1:  requiredFlag = .command
        case 2:  requiredFlag = .option
        default: requiredFlag = .control  // Default: Control (^)
        }

        // Bail out if the required modifier is not currently held.
        guard event.modifierFlags.contains(requiredFlag) else { return }

        // Ignore trackpad momentum (the deceleration phase after a flick).
        guard event.momentumPhase == [] || event.momentumPhase == .stationary else {
            scrollAccumulator = 0  // Reset so stale momentum doesn't trigger late steps.
            return
        }

        // Prefer the continuous (trackpad) delta; fall back to the discrete
        // (mouse wheel) delta scaled to a comparable magnitude.
        let rawDelta: Double = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY)
            : Double(event.deltaY) * 8.0

        guard abs(rawDelta) > 0 else { return }

        // Reset accumulator if the user reverses scroll direction mid-gesture.
        if scrollAccumulator != 0 && (rawDelta > 0) != (scrollAccumulator > 0) {
            scrollAccumulator = 0
        }

        // Determine zoom direction, honouring the "invert scroll" preference.
        let zoomIn = settings.invertScroll ? rawDelta < 0 : rawDelta > 0

        scrollAccumulator += rawDelta > 0 ? abs(rawDelta) : -abs(rawDelta)

        // Speed 10 -> threshold ~2 (very responsive)
        // Speed 5  -> threshold ~12 (moderate)
        // Speed 1  -> threshold ~20 (slow)
        let threshold = max(2.0, 22.0 - Double(settings.zoomSpeed) * 2.0)

        // Cap the accumulator to prevent a runaway burst from very fast scrolling.
        let maxAccumulator = threshold * 5
        if scrollAccumulator > maxAccumulator { scrollAccumulator = maxAccumulator }
        if scrollAccumulator < -maxAccumulator { scrollAccumulator = -maxAccumulator }

        // Fire one zoom keystroke per completed threshold unit.
        while abs(scrollAccumulator) >= threshold {
            scrollAccumulator -= scrollAccumulator > 0 ? threshold : -threshold
            postZoomKey(zoomIn: zoomIn)
        }
    }

    // MARK: - Keystroke synthesis

    /// Posts a synthetic Cmd+= (zoom in) or Cmd+- (zoom out) event to the
    /// session so the currently-focused application receives it.
    private func postZoomKey(zoomIn: Bool) {
        // kVK_ANSI_Equal = 0x18  ->  Cmd+= zooms in  (recognised by most macOS apps)
        // kVK_ANSI_Minus = 0x1B  ->  Cmd+- zooms out (recognised by most macOS apps)
        let keyCode: CGKeyCode = zoomIn ? 0x18 : 0x1B

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            log.error("CGEvent creation failed for keyCode \(keyCode).")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        // Post to the annotated session tap so the event reaches the frontmost app.
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
