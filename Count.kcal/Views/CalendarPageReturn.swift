import SwiftUI

/// A distant return has two completion conditions: the slide must finish, then
/// the persistent native viewport must confirm the destination is aligned.
struct CalendarReturnState {
    private(set) var nativeRequest: CalendarScrollRequest
    var nativeSelection: Date { nativeRequest.selection }
    var animatesNativeScroll: Bool { nativeRequest.animated }
    private(set) var flight: Flight?

    struct Flight: Equatable {
        let id = UUID()
        let source: Date
        let target: Date
        var isReanchoring = false
    }

    var isReanchoring: Bool { flight?.isReanchoring == true }

    init(selection: Date) {
        nativeRequest = CalendarScrollRequest(selection: selection, animated: false)
    }

    mutating func select(_ target: Date, animated: Bool, pageDays: Int, followsGesture: Bool = false, calendar: Calendar = .current) {
        let distance = abs(calendar.dateComponents([.day], from: nativeSelection, to: target).day ?? 0)
        if animated && (flight != nil || distance > pageDays) {
            // Keep the overlay alive. SwiftUI retargets its existing move transitions
            // from their current presentation, including a reversal to the source.
            flight = Flight(source: flight?.target ?? nativeSelection, target: target)
        } else {
            flight = nil
            nativeRequest = CalendarScrollRequest(selection: target, animated: animated, followsGesture: followsGesture)
        }
    }

    mutating func completeAnimation(id: UUID) {
        guard flight?.id == id, let target = flight?.target else { return }
        flight?.isReanchoring = true
        nativeRequest = CalendarScrollRequest(selection: target, animated: false)
    }

    @discardableResult
    mutating func arrive(at date: Date, requestID: UUID) -> Bool {
        guard isReanchoring, flight?.target == date, nativeRequest.id == requestID else { return false }
        flight = nil
        return true
    }
}

/// A command has identity even when its destination matches the old native selection.
/// This lets cancellation replace an in-flight scroll back to that same destination.
struct CalendarScrollRequest: Equatable {
    let id = UUID()
    let selection: Date
    let animated: Bool
    var followsGesture = false

    func requiresScroll(visibleID: Date?) -> Bool {
        !followsGesture || visibleID != selection
    }

    func requiresAlignmentCorrection(alignedID: Date?, isUserScrolling: Bool) -> Bool {
        !isUserScrolling && alignedID != nil && alignedID != selection
    }
}

/// Keeps the native viewport alive while a distant selection travels one page.
/// SwiftUI owns interruption of the slide; geometry confirms the native handoff.
struct CalendarPageReturn<Pager: View, Destination: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let selection: Date
    let animated: Bool
    let pageDays: Int
    let followsGesture: Bool
    @ViewBuilder let pager: (CalendarScrollRequest, Bool, @escaping (Date, UUID) -> Void) -> Pager
    @ViewBuilder let destination: (Date) -> Destination

    @State private var navigation: CalendarReturnState

    init(selection: Date, animated: Bool, pageDays: Int, followsGesture: Bool,
         @ViewBuilder pager: @escaping (CalendarScrollRequest, Bool, @escaping (Date, UUID) -> Void) -> Pager,
         @ViewBuilder destination: @escaping (Date) -> Destination) {
        self.selection = selection
        self.animated = animated
        self.pageDays = pageDays
        self.followsGesture = followsGesture
        self.pager = pager
        self.destination = destination
        _navigation = State(initialValue: CalendarReturnState(selection: selection))
    }

    var body: some View {
        pager(navigation.nativeRequest, navigation.flight == nil, arrived)
            .opacity(navigation.flight == nil ? 1 : 0)
            .animation(nil, value: navigation.flight == nil)
            .allowsHitTesting(navigation.flight == nil)
            .overlay(alignment: .topLeading) {
                if let flight = navigation.flight {
                    CalendarReturnOverlay(flight: flight, destination: destination, onCompletion: completed)
                    .transition(.identity)
                }
            }
            .clipped()
            .onChange(of: selection) { _, target in
                var next = navigation
                next.select(target, animated: !followsGesture && animated && !reduceMotion,
                            pageDays: pageDays, followsGesture: followsGesture)
                if followsGesture {
                    withTransaction(Transaction(animation: nil)) { navigation = next }
                } else if next.animatesNativeScroll {
                    // A normal selection must preserve other strips' active gestures.
                    navigation = next
                } else if next.flight != nil {
                    withTransaction(Transaction(animation: nil)) { navigation = next }
                } else {
                    withoutAnimation { navigation = next }
                }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced {
                    withoutAnimation {
                        navigation.select(selection, animated: false, pageDays: pageDays)
                    }
                }
            }
    }

    private func completed(_ id: UUID) {
        guard navigation.flight?.id == id, !navigation.isReanchoring else { return }
        withoutAnimation { navigation.completeAnimation(id: id) }
    }

    private func arrived(_ date: Date, requestID: UUID) {
        var next = navigation
        guard next.arrive(at: date, requestID: requestID) else { return }
        withoutAnimation { navigation = next }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}

/// Stable container identity lets SwiftUI reverse or replace an unfinished slide.
/// Removed pages live only for the duration of their native move transition.
private struct CalendarReturnOverlay<Destination: View>: View {
    let flight: CalendarReturnState.Flight
    @ViewBuilder let destination: (Date) -> Destination
    let onCompletion: (UUID) -> Void
    @State private var displayedDay: Date

    init(flight: CalendarReturnState.Flight,
         @ViewBuilder destination: @escaping (Date) -> Destination,
         onCompletion: @escaping (UUID) -> Void) {
        self.flight = flight
        self.destination = destination
        self.onCompletion = onCompletion
        _displayedDay = State(initialValue: flight.source)
    }

    var body: some View {
        GeometryReader { geometry in
            let forward = flight.target > flight.source
            ZStack(alignment: .topLeading) {
                destination(displayedDay)
                    .frame(width: geometry.size.width)
                    .id(displayedDay)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading),
                        removal: .move(edge: forward ? .leading : .trailing)
                    ))
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .geometryGroup()
        }
        .onAppear { depart() }
        .onChange(of: flight.id) { depart() }
    }

    private func depart() {
        let id = flight.id
        var transaction = Transaction(animation: .snappy)
        transaction.disablesAnimations = false
        transaction.addAnimationCompletion(criteria: .removed) { onCompletion(id) }
        withTransaction(transaction) { displayedDay = flight.target }
    }
}

private enum CalendarPageLocation: Equatable {
    case outside, centered, aligned
}

private struct CalendarPagePosition: ViewModifier {
    let id: Date
    let request: CalendarScrollRequest
    let viewport: Namespace.ID
    let onCenter: (Date) -> Void
    let onAlignment: (Date) -> Void
    let onArrival: (Date, UUID) -> Void
    @State private var location = CalendarPageLocation.outside

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CalendarPageLocation.self) { geometry in
                let width = geometry.size.width
                let offset = abs(geometry.frame(in: .named(viewport)).minX)
                guard width > 0, offset < width / 2 else { return .outside }
                return offset < 1 ? .aligned : .centered
            } action: { location in
                self.location = location
                if location != .outside { onCenter(id) }
                if location == .aligned {
                    onAlignment(id)
                    reportArrival()
                }
            }
            .onChange(of: request.id) { reportArrival() }
    }

    private func reportArrival() {
        guard location == .aligned, id == request.selection else { return }
        onArrival(id, request.id)
    }
}

extension View {
    /// Geometry describes presentation only. Command changes cannot manufacture
    /// midpoint crossings, but can acknowledge an already-aligned destination.
    func calendarPagePosition(
        id: Date, request: CalendarScrollRequest, viewport: Namespace.ID,
        onCenter: @escaping (Date) -> Void, onAlignment: @escaping (Date) -> Void, onArrival: @escaping (Date, UUID) -> Void
    ) -> some View {
        modifier(CalendarPagePosition(id: id, request: request, viewport: viewport,
                                      onCenter: onCenter, onAlignment: onAlignment, onArrival: onArrival))
    }
}
