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
//  • NSEvent.addGlobalMonitorForEvents is used instead of a CGEventTap.
//    Both approaches require Accessibility permission, but the global monitor
//    API is fully sandbox-compatible and accepted by the Mac App Store.
//    The trade-off: we *cannot* consume (suppress) the original scroll event.
//    In apps that already handle Ctrl+Scroll natively (e.g. Chrome, Safari)
//    users will see a double-zoom step; they should switch the trigger key
//    to Option or Command in Settings to avoid this.
//
//  • Accumulator design: rather than firing a zoom keystroke on every scroll
//    tick, scroll deltas are accumulated until they cross a configurable
//    threshold.  This prevents a single "nudge" of the mouse wheel from
//    zooming multiple levels and makes the speed feel proportional.
//
//  • Trackpad vs. mouse wheel: trackpad events set hasPreciseScrollingDeltas
//    and report small floating-point values per frame.  Mouse wheel events
//    report integer deltaY values (typically ±1 per click).  We scale the
//    mouse-wheel delta by 8× so both input devices feel equally responsive
//    at the same speed setting.
//
//  • Thread safety: `ZoomEngine` is annotated `@MainActor` so the compiler
//    enforces that `eventMonitor` and `scrollAccumulator` are always accessed
//    on the main thread.  NSEvent global monitor callbacks already arrive on
//    the main thread; `@MainActor` makes that contract explicit and checked.
//
//  Key codes used
//  ──────────────
//  kVK_ANSI_Equal  = 0x18  →  Cmd+= zooms in  (broadly supported by macOS apps)
//  kVK_ANSI_Minus  = 0x1B  →  Cmd+- zooms out (broadly supported by macOS apps)
//

import Cocoa
import ApplicationServices  // AXIsProcessTrusted
import os.log

/// Singleton responsible for monitoring global scroll events and posting
/// synthetic zoom keystrokes to the currently-focused application.
///
/// `@MainActor` ensures all mutable state (`eventMonitor`, `scrollAccumulator`)
/// is accessed exclusively on the main thread, matching the thread on which
/// `NSEvent` global monitor callbacks are delivered.
///
/// Usage:
/// ```swift
/// ZoomEngine.shared.start()   // begin monitoring
/// ZoomEngine.shared.stop()    // stop monitoring
/// ```
@MainActor
final class ZoomEngine {

    // MARK: - Shared instance

    /// The single application-wide instance.
    static let shared = ZoomEngine()

    // MARK: - Private state

    /// Token returned by `NSEvent.addGlobalMonitorForEvents`.
    /// Non-nil while the monitor is active; nil when stopped.
    private var eventMonitor: Any?

    /// Running total of scroll delta between zoom steps.
    /// Resets to 0 when the scroll direction reverses or when `stop()` is called.
    private var scrollAccumulator: Double = 0

    /// Structured log — entries appear in Console.app under the WinZoom subsystem.
    private let log = Logger(subsystem: "com.dylanbatt.WinZoom", category: "ZoomEngine")

    // MARK: - Init

    /// Private to enforce the singleton pattern.
    private init() {}

    // MARK: - Public API

    /// `true` while the global scroll-event monitor is active.
    var isRunning: Bool { eventMonitor != nil }

    /// Installs the global scroll-event monitor and begins intercepting
    /// scroll events.
    ///
    /// Safe to call multiple times — subsequent calls while already running
    /// are ignored.  Requires Accessibility permission; logs a warning and
    /// returns early if it has not been granted.
    func start() {
        // Prevent installing a second monitor if already running.
        guard eventMonitor == nil else { return }

        // Accessibility permission is required for global event monitoring.
        guard AXIsProcessTrusted() else {
            log.warning("Accessibility permission not granted — zoom engine not started.")
            return
        }

        // Install the global monitor.  The closure is called on the main
        // thread for every .scrollWheel event fired by any application.
        // [weak self] prevents a retain cycle if the monitor outlives self
        // (shouldn't happen with a singleton, but is good practice).
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }

        if eventMonitor != nil {
            log.info("ZoomEngine started.")
        } else {
            // addGlobalMonitorForEvents returns nil when the system refuses
            // to install the tap — most commonly because Accessibility was
            // revoked after the app launched.
            log.error("addGlobalMonitorForEvents returned nil — check Accessibility permission.")
        }
    }

    /// Removes the global scroll-event monitor and resets the accumulator.
    ///
    /// Safe to call when already stopped — the guard handles that case.
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            // Reset accumulator so stale delta doesn't carry over into the
            // next monitoring session.
            scrollAccumulator = 0
            log.info("ZoomEngine stopped.")
        }
    }

    // MARK: - Event handling

    /// Central handler for every scroll-wheel event.
    ///
    /// Steps performed:
    /// 1. Check that the required modifier key is held.
    /// 2. Discard momentum-phase events (trackpad deceleration after a flick).
    /// 3. Normalise the raw delta across trackpad and mouse-wheel inputs.
    /// 4. Accumulate the delta and fire zoom keystrokes when the threshold
    ///    is crossed.
    private func handleScrollEvent(_ event: NSEvent) {
        let settings = SettingsManager.shared

        // ── 1. Modifier-key check ──────────────────────────────────────────
        // The ModifierKey enum provides the matching NSEvent.ModifierFlags
        // directly, eliminating the need for a raw-Int switch statement.
        let requiredFlag = settings.modifierKey.eventFlag

        // If the required modifier isn't held, this scroll is not for us.
        guard event.modifierFlags.contains(requiredFlag) else { return }

        // ── 2. Momentum phase filter ───────────────────────────────────────
        // After the user lifts their fingers from a trackpad, macOS continues
        // to fire synthetic "momentum" scroll events to simulate deceleration.
        // We ignore these so a quick flick doesn't trigger unexpected zoom
        // steps long after the gesture ends.
        guard event.momentumPhase == [] || event.momentumPhase == .stationary else {
            // Reset the accumulator so leftover momentum can't build up and
            // trigger a zoom step on the next intentional scroll.
            scrollAccumulator = 0
            return
        }

        // ── 3. Delta normalisation ─────────────────────────────────────────
        // Trackpad: hasPreciseScrollingDeltas = true; scrollingDeltaY is a
        //           small float (e.g. ±1..±10 per frame at moderate speed).
        // Mouse wheel: deltaY is an integer (typically ±1 per detent click).
        //              We scale it by 8 to reach a comparable magnitude so
        //              both devices feel equally responsive.
        let rawDelta: Double = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY)
            : Double(event.deltaY) * 8.0

        // Skip events with no movement (can happen on some trackpad gestures).
        guard abs(rawDelta) > 0 else { return }

        // ── 4. Direction-change reset ──────────────────────────────────────
        // If the user reverses scroll direction mid-gesture, discard the
        // accumulated delta so the new direction starts from zero rather than
        // having to "unwind" the previous total first.
        if scrollAccumulator != 0 && (rawDelta > 0) != (scrollAccumulator > 0) {
            scrollAccumulator = 0
        }

        // Determine the intended zoom direction, optionally inverting it.
        // Default (non-inverted): scroll up (positive delta) → zoom in.
        let zoomIn = settings.invertScroll ? rawDelta < 0 : rawDelta > 0

        // Add the signed delta to the accumulator.
        scrollAccumulator += rawDelta > 0 ? abs(rawDelta) : -abs(rawDelta)

        // ── 5. Threshold calculation ───────────────────────────────────────
        // The threshold controls how much accumulated delta is needed before
        // a zoom keystroke fires.  It is derived from the user's speed setting:
        //
        //   Speed 10 → threshold ≈  2  (very responsive — fires almost every frame)
        //   Speed  5 → threshold ≈ 12  (moderate — natural feel)
        //   Speed  1 → threshold ≈ 20  (slow — one click zooms only occasionally)
        //
        // Formula: threshold = max(2.0, 22.0 − (speed × 2.0))
        let threshold = max(2.0, 22.0 - Double(settings.zoomSpeed) * 2.0)

        // Cap the accumulator to 5× the threshold to prevent a runaway burst
        // from a very fast flick triggering an enormous number of zoom steps.
        let maxAccumulator = threshold * 5
        if scrollAccumulator >  maxAccumulator { scrollAccumulator =  maxAccumulator }
        if scrollAccumulator < -maxAccumulator { scrollAccumulator = -maxAccumulator }

        // ── 6. Keystroke dispatch ──────────────────────────────────────────
        // Consume threshold-sized chunks of the accumulator and fire one zoom
        // keystroke per chunk.  The while loop handles the (rare) case where
        // fast scrolling has pushed the accumulator past 2× the threshold.
        while abs(scrollAccumulator) >= threshold {
            scrollAccumulator -= scrollAccumulator > 0 ? threshold : -threshold
            postZoomKey(zoomIn: zoomIn)
        }
    }

    // MARK: - Keystroke synthesis

    /// Synthesises and posts a Cmd+= (zoom in) or Cmd+- (zoom out) CGEvent
    /// to the currently-focused application.
    ///
    /// `CGEvent(keyboardEventSource:virtualKey:keyDown:)` creates a low-level
    /// HID keyboard event.  Posting to `.cgAnnotatedSessionEventTap` delivers
    /// it to the session's event stream so the frontmost app receives it as if
    /// the user had pressed the key combination on a physical keyboard.
    ///
    /// - Parameter zoomIn: `true` fires Cmd+=; `false` fires Cmd+-.
    private func postZoomKey(zoomIn: Bool) {
        // Virtual key codes (from Carbon/HIToolbox Events.h):
        //   kVK_ANSI_Equal = 0x18  →  the "=" / "+" key
        //   kVK_ANSI_Minus = 0x1B  →  the "-" / "_" key
        //
        // Cmd+= and Cmd+- are the standard zoom in/out shortcuts recognised
        // by virtually all macOS applications (Safari, Finder, Terminal, etc.).
        let keyCode: CGKeyCode = zoomIn ? 0x18 : 0x1B

        // Create matching key-down and key-up events.
        // Using source: nil lets the system assign a default event source.
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            // This should never happen in practice; log if it does.
            log.error("CGEvent creation failed for keyCode \(keyCode).")
            return
        }

        // Apply the Command modifier flag to both events so the receiving
        // app interprets them as Cmd+= / Cmd+- rather than bare = / -.
        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        // Post to the annotated session tap — the correct tap point for
        // delivering synthetic events to the frontmost application without
        // them being filtered by the window server's security checks.
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
