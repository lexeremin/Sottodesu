import SwiftUI

/// One spinning wheel, like the time picker on an iPhone. Scroll, drag or click a number:
/// the one in the middle is the choice.
struct Wheel: View {
    struct Item: Identifiable {
        let id: Int
        let label: String
    }

    let items: [Item]
    @Binding var selection: Int
    var width: CGFloat = 64

    @State private var position: Int?

    private let rowHeight: CGFloat = 34
    private let visibleRows: CGFloat = 5

    init(items: [Item], selection: Binding<Int>, width: CGFloat = 64) {
        self.items = items
        self._selection = selection
        self.width = width
        self._position = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        let viewport = rowHeight * visibleRows
        let row = rowHeight

        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Text(item.label)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .frame(width: width, height: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) { position = item.id }
                        }
                        // The curve of the drum: numbers away from the middle fade, shrink and tilt.
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .named("wheel"))
                            let distance = max(-2.5, min(2.5, (frame.midY - viewport / 2) / row))
                            return content
                                .opacity(1 - abs(distance) * 0.28)
                                .scaleEffect(1 - abs(distance) * 0.05)
                                .rotation3DEffect(.degrees(Double(distance) * -20), axis: (x: 1, y: 0, z: 0),
                                                  perspective: 0.5)
                        }
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, (viewport - rowHeight) / 2)
        }
        .coordinateSpace(name: "wheel")
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .frame(width: width, height: viewport)
        .onChange(of: position) { _, new in
            if let new, new != selection { selection = new }
        }
        .onChange(of: selection) { _, new in
            if position != new { withAnimation(.easeOut(duration: 0.2)) { position = new } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(items.first { $0.id == selection }?.label ?? "")
        .accessibilityAdjustableAction { direction in
            guard let index = items.firstIndex(where: { $0.id == selection }) else { return }
            switch direction {
            case .increment: if index + 1 < items.count { selection = items[index + 1].id }
            case .decrement: if index > 0 { selection = items[index - 1].id }
            @unknown default: break
            }
        }
    }
}

/// Hours and minutes on two wheels (plus AM/PM where your region uses it), inside a soft highlight band.
struct TimeWheel: View {
    @Binding var hour: Int      // 0…23
    @Binding var minute: Int    // 0…59

    private let calendar = Calendar.current
    private var uses12Hour: Bool {
        let cycle = Locale.current.hourCycle
        return cycle == .zeroToEleven || cycle == .oneToTwelve
    }

    private var hour12: Binding<Int> {
        Binding(get: { hour % 12 == 0 ? 12 : hour % 12 },
                set: { hour = ($0 % 12) + (hour >= 12 ? 12 : 0) })
    }

    private var meridiem: Binding<Int> {
        Binding(get: { hour >= 12 ? 1 : 0 },
                set: { hour = (hour % 12) + ($0 == 1 ? 12 : 0) })
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(height: 34)

            HStack(spacing: 0) {
                if uses12Hour {
                    Wheel(items: (1...12).map { Wheel.Item(id: $0, label: "\($0)") }, selection: hour12)
                } else {
                    Wheel(items: (0...23).map { Wheel.Item(id: $0, label: String(format: "%02d", $0)) }, selection: $hour)
                }
                Text(verbatim: ":")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .frame(width: 12)
                Wheel(items: (0...59).map { Wheel.Item(id: $0, label: String(format: "%02d", $0)) }, selection: $minute)
                if uses12Hour {
                    Wheel(items: [Wheel.Item(id: 0, label: calendar.amSymbol), Wheel.Item(id: 1, label: calendar.pmSymbol)],
                          selection: meridiem, width: 60)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 170)
        // Fade the top and bottom so the numbers seem to curve away.
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.28),
                .init(color: .black, location: 0.72),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
        .fixedSize()
    }
}
