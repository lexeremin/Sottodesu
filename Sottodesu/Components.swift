import AppKit
import SwiftUI

// MARK: - Brand

/// The Sottodesu mark: a red sun over three bars sorted from long to short.
/// The same drawing is used for the app icon (see Tools/make_icon.py).
struct SortMark: View {
    var body: some View {
        Canvas { context, size in
            let u = size.width / 100
            let sun = CGRect(x: 54 * u, y: 2 * u, width: 40 * u, height: 40 * u)
            context.fill(Path(ellipseIn: sun), with: .color(.accentColor))

            let bars: [(y: CGFloat, length: CGFloat)] = [(54, 88), (70, 66), (86, 44)]
            for bar in bars {
                let rect = CGRect(x: 6 * u, y: bar.y * u, width: bar.length * u, height: 8 * u)
                context.fill(Path(roundedRect: rect, cornerRadius: 4 * u), with: .color(.primary))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A filled button that lifts and brightens on hover and settles when pressed.
struct SortButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        private var lifted: Bool { hovering && isEnabled }

        var body: some View {
            configuration.label
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .frame(minWidth: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .brightness(lifted ? 0.07 : 0)
                .shadow(color: Color.accentColor.opacity(lifted ? 0.4 : 0), radius: 12, y: 4)
                .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.97 : (lifted ? 1.03 : 1))
                .animation(.easeOut(duration: 0.15), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

// MARK: - Surfaces

extension View {
    /// A quiet card: a hairline border on a slightly raised surface. Works in light and dark.
    func cardBackground(cornerRadius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct Card<Content: View>: View {
    let title: LocalizedStringKey?
    let subtitle: LocalizedStringKey?
    let content: Content

    init(_ title: LocalizedStringKey? = nil, subtitle: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bars

/// A thin stacked bar showing how a sort divides between categories.
struct CategoryBar: View {
    let counts: [CategoryCount]

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(max(counts.reduce(0) { $0 + $1.count }, 1))
            let gaps = CGFloat(max(counts.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(counts, id: \.name) { entry in
                    Rectangle()
                        .fill(Theme.color(forGroup: entry.name))
                        .frame(width: max(3, (geo.size.width - gaps) * CGFloat(entry.count) / total))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// A horizontal bar for comparing shares in a table row.
struct ShareBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
