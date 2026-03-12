//
//  AboutView.swift
//  WinZoom
//
//  Displays app identity, developer credit, contact links, and a brief
//  call-to-action for custom app development enquiries.
//
//  URL safety note
//  ───────────────
//  All URL strings are compile-time constants pointing to well-formed
//  https / mailto addresses.  Force-unwrapping `URL(string:)` with `!` is
//  acceptable here because a nil result would indicate a programmer error
//  (malformed literal) that would be caught immediately during development —
//  it is NOT a runtime condition that could arise from user input or network
//  data.  Using `!` is intentional and preferable to adding unnecessary
//  optional-handling boilerplate for constants that are always valid.
//

import SwiftUI

struct AboutView: View {

    // MARK: - Constants

    /// Developer website — opened when the user taps "Visit Site" or the
    /// "dylanbatt.com" text link.
    private let websiteURL = URL(string: "https://dylanbatt.com/")!

    /// Developer email — opened in the default mail client when the user
    /// taps "Email Me" or the "info@dylanbatt.com" text link.
    private let emailURL   = URL(string: "mailto:info@dylanbatt.com")!

    /// The human-readable version string read from the app bundle's Info.plist
    /// (`CFBundleShortVersionString`).  Falls back to "1.0" if the key is
    /// missing (e.g. during SwiftUI previews before the bundle is fully built).
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Developer logo ─────────────────────────────────────────────
            // The "DylanBattLogo" asset is a custom image in Assets.xcassets.
            // resizable() + aspectRatio(.fit) ensures it scales proportionally
            // within its container; maxWidth: .infinity stretches it to the
            // available width up to the 340 pt frame set below.
            Image("DylanBattLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 20)

            // ── App identity ───────────────────────────────────────────────
            VStack(spacing: 6) {
                // Mirror the menu bar icon for visual continuity.
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)   // Uses the app's accent colour.

                Text("WinZoom")
                    .font(.title2.bold())

                // Version read from CFBundleShortVersionString in Info.plist —
                // automatically stays in sync with the Xcode project version.
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 16)

            // ── Developer credit ───────────────────────────────────────────
            VStack(spacing: 8) {
                Text("Developed by")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Dylan Batt")
                    .font(.headline)

                // Website and email shown side-by-side with a centred dot
                // separator.  SwiftUI's Link opens the URL in the default
                // browser / mail client without any extra code.
                HStack(spacing: 16) {
                    Link("dylanbatt.com", destination: websiteURL)
                        .font(.subheadline)
                        .foregroundStyle(.tint)

                    Text("·")
                        .foregroundStyle(.tertiary)  // Subtle visual separator.

                    Link("info@dylanbatt.com", destination: emailURL)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }

            Divider()
                .padding(.vertical, 16)

            // ── Hire / contact section ─────────────────────────────────────
            // A GroupBox gives this section a subtle visual container to
            // distinguish it from the identity information above.
            GroupBox {
                VStack(spacing: 8) {
                    Text("Need an app built?")
                        .font(.subheadline.bold())

                    Text("If you require any apps developed, feel free to get in touch — I'd love to help bring your idea to life.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        // Primary CTA: email (borderedProminent = filled button).
                        Link(destination: emailURL) {
                            Label("Email Me", systemImage: "envelope.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        // Secondary CTA: website (bordered = outlined button).
                        Link(destination: websiteURL) {
                            Label("Visit Site", systemImage: "safari.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(4)
            }

            // Push copyright to the bottom while maintaining a minimum gap.
            Spacer(minLength: 16)

            // ── Copyright footer ───────────────────────────────────────────
            Text("© 2026 Dylan Batt. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(24)
        // Fixed width of 340 pt; height determined by fixedSize() so the
        // window is always exactly as tall as the content requires.
        .frame(width: 340)
        .fixedSize()
    }
}

#Preview {
    AboutView()
}

