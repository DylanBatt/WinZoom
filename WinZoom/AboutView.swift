//
//  AboutView.swift
//  WinZoom
//
//  Displays app identity, developer credit, contact links, and a brief
//  call-to-action for custom app development enquiries.
//
//  URL safety: all URL strings are compile-time constants pointing to
//  well-formed https/mailto addresses, so force-unwrapping URL(string:)
//  is acceptable — a nil result would indicate a programmer error caught
//  immediately in testing, not a runtime condition.
//

import SwiftUI

struct AboutView: View {

    // MARK: - Constants

    private let websiteURL = URL(string: "https://dylanbatt.com/")!
    private let emailURL   = URL(string: "mailto:info@dylanbatt.com")!

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Developer logo ─────────────────────────────────────────────
            Image("DylanBattLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 20)

            // ── App identity ───────────────────────────────────────────────
            VStack(spacing: 6) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)

                Text("WinZoom")
                    .font(.title2.bold())

                Text("Version 1.0")
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

                // Website and email links side by side.
                HStack(spacing: 16) {
                    Link("dylanbatt.com", destination: websiteURL)
                        .font(.subheadline)
                        .foregroundStyle(.tint)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Link("info@dylanbatt.com", destination: emailURL)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }

            Divider()
                .padding(.vertical, 16)

            // ── Hire / contact section ─────────────────────────────────────
            GroupBox {
                VStack(spacing: 8) {
                    Text("Need an app built?")
                        .font(.subheadline.bold())

                    Text("If you require any apps developed, feel free to get in touch — I'd love to help bring your idea to life.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        // Primary CTA: email.
                        Link(destination: emailURL) {
                            Label("Email Me", systemImage: "envelope.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        // Secondary CTA: website.
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

            Spacer(minLength: 16)

            // ── Copyright footer ───────────────────────────────────────────
            Text("© 2026 Dylan Batt. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 340)
        .fixedSize()
    }
}

#Preview {
    AboutView()
}
