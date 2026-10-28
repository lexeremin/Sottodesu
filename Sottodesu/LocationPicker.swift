import SwiftUI

// MARK: - Flow layout

/// Lays views out left to right and wraps to a new row when the line is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Choice cards

/// A big selectable card, like the product pickers in an online store: an icon, a name, a line of
/// explanation, and a ring plus checkmark when chosen. Used for both "Where to sort" and "What to sort".
struct ChoiceCard: View {
    let symbol: String
    let title: String
    let summary: String
    let isSelected: Bool
    var showsChange = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                        if showsChange {
                            Text("Change…")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                shape.strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                                   lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.title3)
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(color: .black.opacity(hovering ? 0.14 : 0.04), radius: hovering ? 12 : 3, y: hovering ? 5 : 1)
        .scaleEffect(reduceMotion ? 1 : (hovering ? 1.02 : 1))
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Category chips

/// A pill that can be switched on and off, for choosing which kinds of files to sort.
struct CategoryChip: View {
    let title: String
    let symbol: String
    let isOn: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(Capsule().fill(isOn ? Color.accentColor : Color.primary.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(isOn ? 0 : 0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .animation(.easeOut(duration: 0.12), value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - The two pickers

private let cardColumns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

struct LocationPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where to sort")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: cardColumns, spacing: 12) {
                ForEach(LocationKind.allCases) { kind in
                    card(for: kind)
                }
            }

            if model.location == .home {
                Label {
                    Text("Home is limited on purpose: only loose media and documents are moved — photos to Pictures, videos to Movies, music to Music, everything else into Documents. Hidden files, folders, apps, settings, keys, code and databases are never touched.")
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func card(for kind: LocationKind) -> some View {
        let isCustomChosen = kind == .custom && model.customFolder != nil
        let title = isCustomChosen ? (model.customFolder?.lastPathComponent ?? kind.title) : kind.title
        let summary = isCustomChosen
            ? ((model.customFolder?.path ?? "") as NSString).abbreviatingWithTildeInPath
            : kind.summary
        let isSelected = model.location == kind

        return ChoiceCard(symbol: kind.symbol, title: title, summary: summary, isSelected: isSelected,
                          showsChange: isCustomChosen && isSelected) {
            model.choose(kind)
        }
    }
}

struct ScopePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("What to sort")
                    .font(.title3.weight(.semibold))
                Spacer()
                if model.isSelective {
                    Button("Reset") {
                        withAnimation(.easeOut(duration: 0.15)) { model.resetSelection() }
                    }
                    .buttonStyle(.link)
                    .disabled(model.selectedCategories.isEmpty)
                }
            }

            LazyVGrid(columns: cardColumns, spacing: 12) {
                ChoiceCard(symbol: "square.grid.2x2",
                           title: String(localized: "Everything"),
                           summary: String(localized: "All file types, in one go"),
                           isSelected: !model.isSelective) {
                    withAnimation(.easeOut(duration: 0.18)) { model.chooseEverything() }
                }
                ChoiceCard(symbol: "checklist",
                           title: String(localized: "Selective"),
                           summary: String(localized: "Only the types you pick"),
                           isSelected: model.isSelective) {
                    withAnimation(.easeOut(duration: 0.18)) { model.chooseSelective() }
                }
            }

            if model.isSelective {
                FlowLayout(spacing: 8) {
                    ForEach(FileCategory.allCases, id: \.self) { category in
                        let allowed = model.allowedCategories.contains(category)
                        CategoryChip(title: category.displayName, symbol: category.symbol,
                                     isOn: model.selectedCategories.contains(category),
                                     isEnabled: allowed) {
                            model.toggle(category)
                        }
                        .help(allowed ? LocalizedStringKey("") : LocalizedStringKey("Not sorted in this location"))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
