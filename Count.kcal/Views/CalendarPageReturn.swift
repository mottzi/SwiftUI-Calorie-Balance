import SwiftUI

/// A distant return has two completion conditions: the slide must finish, then
/// the persistent native viewport must confirm the destination is aligned.
struct CalendarReturnState {
    private(set) var nativeSelection: Date
    private(set) var animatesNativeScroll = false
    private(set) var flight: Flight?

    struct Flight: Equatable {
        let id = UUID()
        let source: Date
        let target: Date
        var isReanchoring = false
    }

    var isReanchoring: Bool { flight?.isReanchoring == true }

    init(selection: Date) {
        nativeSelection = selection
    }

    mutating func select(_ target: Date, animated: Bool, pageDays: Int, calendar: Calendar = .current) {
        let interrupted = flight != nil
        let distance = abs(calendar.dateComponents([.day], from: nativeSelection, to: target).day ?? 0)
        animatesNativeScroll = animated && !interrupted && distance <= pageDays
        if animated && !interrupted && distance > pageDays {
            flight = Flight(source: nativeSelection, target: target)
        } else {
            // The latest request wins. Keep native animation disabled through
            // handoff/cancellation, including the visibility callback's update.
            flight = nil
            nativeSelection = target
        }
    }

    mutating func completeAnimation(id: UUID) {
        guard flight?.id == id, let target = flight?.target else { return }
        flight?.isReanchoring = true
        nativeSelection = target
    }

    @discardableResult
    mutating func arrive(at date: Date) -> Bool {
        guard isReanchoring, flight?.target == date else { return false }
        flight = nil
        return true
    }
}

/// Keeps the native viewport alive while a distant selection travels one page.
/// The destination stays in place until the native page reports alignment with the viewport.
struct CalendarPageReturn<Pager: View, Destination: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    let selection: Date
    let animated: Bool
    let pageDays: Int
    @ViewBuilder let pager: (Date, Bool, @escaping (Date) -> Void) -> Pager
    @ViewBuilder let destination: (Date) -> Destination

    @State private var navigation: CalendarReturnState
    @State private var progress: CGFloat = 0

    init(selection: Date, animated: Bool, pageDays: Int,
         @ViewBuilder pager: @escaping (Date, Bool, @escaping (Date) -> Void) -> Pager,
         @ViewBuilder destination: @escaping (Date) -> Destination) {
        self.selection = selection
        self.animated = animated
        self.pageDays = pageDays
        self.pager = pager
        self.destination = destination
        _navigation = State(initialValue: CalendarReturnState(selection: selection))
    }

    var body: some View {
        pager(navigation.nativeSelection, navigation.animatesNativeScroll, arrived)
            .opacity(navigation.flight == nil ? 1 : 0)
            .animation(nil, value: navigation.flight == nil)
            .overlay(alignment: .topLeading) {
                if let flight = navigation.flight {
                    GeometryReader { geometry in
                        let forward = flight.target > flight.source
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(forward ? [flight.source, flight.target] : [flight.target, flight.source], id: \.self) { date in
                                destination(date)
                                    .frame(width: geometry.size.width)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: geometry.size.width, alignment: .leading)
                        .geometryGroup()
                        .offset(x: ((forward ? 0 : -1) - progress) * geometry.size.width
                                * (layoutDirection == .leftToRight ? 1 : -1))
                    }
                    .transition(.identity)
                    .accessibilityHidden(true)
                    .onAppear { depart(flight) }
                }
            }
        .clipped()
        .allowsHitTesting(navigation.flight == nil)
        .onChange(of: selection) { _, target in
            var next = navigation
            next.select(target, animated: animated && !reduceMotion, pageDays: pageDays)
            if next.flight != nil {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = false
                withTransaction(transaction) {
                    navigation = next
                    progress = 0
                }
            } else if next.animatesNativeScroll {
                navigation = next
            } else {
                withoutAnimation {
                    navigation = next
                    progress = 0
                }
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                withoutAnimation {
                    navigation.select(selection, animated: false, pageDays: pageDays)
                    progress = 0
                }
            }
        }
    }

    private func depart(_ departing: CalendarReturnState.Flight) {
        var transaction = Transaction(animation: .snappy)
        transaction.addAnimationCompletion(criteria: .removed) {
            withoutAnimation { navigation.completeAnimation(id: departing.id) }
        }
        withTransaction(transaction) {
            progress = departing.target > departing.source ? 1 : -1
        }
    }

    private func arrived(_ date: Date) {
        withoutAnimation {
            if navigation.arrive(at: date) { progress = 0 }
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}

private enum CalendarPageLocation: Equatable {
    case outside, centered, aligned
}

extension View {
    /// Track horizontal selection independently of vertical clipping or large text.
    /// Only midpoint crossings and arrival leave geometry, never per-frame offsets.
    func calendarPagePosition(
        id: Date, selection: Date, viewport: Namespace.ID,
        onCenter: @escaping (Date) -> Void, onArrival: @escaping (Date) -> Void
    ) -> some View {
        onGeometryChange(for: CalendarPageLocation.self) { geometry in
            let width = geometry.size.width
            let offset = abs(geometry.frame(in: .named(viewport)).minX)
            guard width > 0, offset < width / 2 else { return .outside }
            return id == selection && offset < 1 ? .aligned : .centered
        } action: { location in
            if location != .outside { onCenter(id) }
            if location == .aligned { onArrival(id) }
        }
    }
}
