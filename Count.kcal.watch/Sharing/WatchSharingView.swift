import SwiftUI

/// A watch-native, read-only people list. Consent changes stay on iPhone except pausing.
struct WatchSharingView: View {
    @Environment(WatchSharingStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let snapshot = store.snapshot, !snapshot.people.isEmpty {
                List(snapshot.people) { person in
                    NavigationLink {
                        WatchSharingPersonView(connectionID: person.id)
                    } label: {
                        WatchSharingRow(
                            person: person.current(at: context.date),
                            hidesGoalStatus: snapshot.hidesGoalStatus,
                            pauseRequested: store.pendingPauses.contains { $0.connectionID == person.id }
                        )
                    }
                }
                .listStyle(.carousel)
                .animation(reduceMotion ? nil : .smooth, value: snapshot.people)
            } else {
                ContentUnavailableView {
                    Label("No shared people", systemImage: "person.2")
                } description: {
                    Text(store.snapshot == nil
                         ? "Open Count.kcal on your iPhone to sync sharing."
                         : "Invite people from Sharing on your iPhone.")
                }
            }
        }
        .navigationTitle("Sharing")
        .toolbarTitleDisplayMode(.large)
        .task { Connectivity.shared.requestSharingUpdate() }
    }
}

private struct WatchSharingRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    let person: WatchSharingSnapshot.Person
    let hidesGoalStatus: Bool
    let pauseRequested: Bool

    var body: some View {
        HStack(spacing: 8) {
            if !dynamicType.isAccessibilitySize {
                WatchSharingRing(snapshot: person.summary, mode: .now, hidesGoalStatus: hidesGoalStatus)
                    .frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)
                    .foregroundStyle(person.nameColor?.color(in: .dark) ?? .primary)
                    .lineLimit(1)
                if pauseRequested {
                    Text("Pause requested").font(.caption2)
                    Text("Waiting for iPhone").font(.caption2).foregroundStyle(.secondary)
                } else if let snapshot = person.summary {
                    WatchSharingBalanceText(values: snapshot.now, unit: snapshot.energyUnit.rawValue)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    WatchSharingTimestamp(date: snapshot.capturedAt, isMissing: false)
                } else {
                    Text(person.status).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if person.scopes.contains(.today), let date = person.lastSharedAt {
                        WatchSharingTimestamp(date: date, isMissing: true)
                    } else {
                        Text(person.scopes.isEmpty ? "Resume on iPhone" : "Updates from iPhone")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityValue(goalAccessibility)
    }

    private var goalAccessibility: Text {
        guard !hidesGoalStatus, let values = person.summary?.now,
              !values.energy.isEmpty, let reached = values.visibleGoalReached else { return Text("") }
        return reached ? Text("Goal reached") : Text("Goal not reached")
    }
}

struct WatchSharingPersonView: View {
    @Environment(WatchSharingStore.self) private var store
    let connectionID: UUID

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let person = store.snapshot?.people.first(where: { $0.id == connectionID })?.current(at: context.date) {
                WatchSharingPersonContent(person: person, hidesGoalStatus: store.snapshot?.hidesGoalStatus ?? true)
            } else {
                ContentUnavailableView("Sharing ended", systemImage: "person.2.slash")
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct WatchSharingPersonContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode = GraphMode.now

    let person: WatchSharingSnapshot.Person
    let hidesGoalStatus: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let today = person.today {
                    WatchSharingDayCard(snapshot: today, mode: mode, hidesGoalStatus: hidesGoalStatus)
                } else {
                    WatchSharingEmptyPerson(person: person)
                }
                if let streak = person.streak {
                    Label {
                        Text("\(streak.days) day streak")
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(streak.color.color(in: .dark))
                    }
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.quaternary, in: .capsule)
                }
                if !person.history.isEmpty {
                    WatchSharingHistory(snapshots: person.history, hidesGoalStatus: hidesGoalStatus)
                }
                WatchSharingPauseControl(person: person)
            }
            .scenePadding(.horizontal)
            .padding(.bottom, 12)
        }
        .navigationTitle(person.name)
        .containerBackground((person.nameColor?.color(in: .dark) ?? .gray).opacity(0.18).gradient, for: .navigation)
        .toolbar {
            if person.today?.midnight != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth) {
                            mode = mode == .now ? .midnight : .now
                        }
                    } label: {
                        Label(mode == .now ? "Show midnight estimate" : "Show current balance",
                              systemImage: mode == .now ? "sun.min.fill" : "moon.stars.fill")
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }
}

private struct WatchSharingEmptyPerson: View {
    let person: WatchSharingSnapshot.Person

    var body: some View {
        VStack(spacing: 8) {
            WatchSharingRing(snapshot: nil, mode: .now, hidesGoalStatus: true)
                .frame(width: 64, height: 64)
                .overlay {
                    if person.scopes.isEmpty {
                        Image(systemName: "pause.fill").foregroundStyle(.secondary)
                    }
                }
            Text(person.status).font(.headline).multilineTextAlignment(.center)
            if person.scopes.contains(.today), let date = person.lastSharedAt {
                Text("Last shared \(Text(date, format: .relative(presentation: .named)))")
                    .font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct WatchSharingDayCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var dynamicType
    let snapshot: CalorieCardSnapshot
    let mode: GraphMode
    let hidesGoalStatus: Bool

    private var values: CalorieCardSnapshot.ModeValues {
        mode == .midnight ? snapshot.midnight ?? snapshot.now : snapshot.now
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(snapshot.dayTitle())
                Spacer(minLength: 4)
                if snapshot.midnight != nil { Text(mode == .now ? "Now" : "Midnight") }
            }
            .font(.caption2).foregroundStyle(.secondary)

            if dynamicType.isAccessibilitySize {
                WatchSharingLargeBalance(values: values, unit: snapshot.energyUnit.rawValue, hidesGoalStatus: hidesGoalStatus)
            } else {
                WatchSharingRing(snapshot: snapshot, mode: mode, hidesGoalStatus: true)
                .frame(height: 104)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(Text(abs(values.balance), format: .number).font(.system(.title2, design: .rounded, weight: .semibold))) \(Text(snapshot.energyUnit.rawValue).font(.caption2))")
                            .contentTransition(.numericText(value: Double(abs(values.balance))))
                            .lineLimit(1).minimumScaleFactor(0.65)
                        Text(values.balanceTitle)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: 64)
                    .offset(y: 2)
                }
                .overlay(alignment: .bottom) {
                    if !hidesGoalStatus, !values.energy.isEmpty, let reached = values.visibleGoalReached {
                        Image(systemName: reached ? "checkmark" : "xmark")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .accessibilityLabel(reached ? "Goal reached" : "Goal not reached")
                            .padding(.bottom, 9)
                    }
                }
                .accessibilityHidden(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(abs(values.balance)) \(snapshot.energyUnit.rawValue) \(Text(values.balanceTitle))"))
                .accessibilityValue(goalAccessibility)
            }

            HStack(alignment: .top, spacing: 12) {
                WatchSharingEnergyTotal(title: "Burned", symbol: "bolt.fill", value: values.burned,
                                        color: snapshot.appearance.burned.color(in: .dark))
                WatchSharingEnergyTotal(title: "Eaten", symbol: "fork.knife", value: values.consumed,
                                        color: snapshot.appearance.consumed.color(in: .dark))
            }
            WatchSharingTimestamp(date: snapshot.capturedAt, isMissing: false)
        }
        .animation(reduceMotion || isLuminanceReduced ? nil : .smooth, value: values)
    }

    private var goalAccessibility: Text {
        guard !hidesGoalStatus, !values.energy.isEmpty, let reached = values.visibleGoalReached else { return Text("") }
        return reached ? Text("Goal reached") : Text("Goal not reached")
    }
}

/// At accessibility sizes the values have their own space, rather than shrinking inside a ring.
private struct WatchSharingLargeBalance: View {
    let values: CalorieCardSnapshot.ModeValues
    let unit: String
    let hidesGoalStatus: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(abs(values.balance), format: .number)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text("\(unit) \(Text(values.balanceTitle))")
                .font(.body).foregroundStyle(.secondary)
            if !hidesGoalStatus, !values.energy.isEmpty, let reached = values.visibleGoalReached {
                Label(reached ? "Goal reached" : "Goal not reached", systemImage: reached ? "checkmark" : "xmark")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct WatchSharingEnergyTotal: View {
    let title: LocalizedStringResource
    let symbol: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Label { Text(value, format: .number).monospacedDigit() } icon: {
                Image(systemName: symbol).foregroundStyle(color)
            }
            .font(.callout.weight(.medium))
            .lineLimit(1).minimumScaleFactor(0.8)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct WatchSharingHistory: View {
    let snapshots: [CalorieCardSnapshot]
    let hidesGoalStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Previous 6 Days").font(.caption2).foregroundStyle(.secondary)
            ForEach(snapshots) { snapshot in
                NavigationLink {
                    ScrollView {
                        WatchSharingDayCard(snapshot: snapshot, mode: .now, hidesGoalStatus: hidesGoalStatus)
                            .scenePadding(.horizontal)
                    }
                    .navigationTitle(Text(snapshot.dayTitle()))
                    .toolbarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.dayTitle()).font(.caption2).foregroundStyle(.secondary)
                        WatchSharingBalanceText(values: snapshot.now, unit: snapshot.energyUnit.rawValue)
                            .font(.callout).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct WatchSharingPauseControl: View {
    @Environment(WatchSharingStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmsPause = false
    let person: WatchSharingSnapshot.Person

    private var isPending: Bool { store.pendingPauses.contains { $0.connectionID == person.id } }

    var body: some View {
        VStack(spacing: 8) {
            if isPending {
                Label("Pause requested", systemImage: "iphone.and.arrow.forward")
                    .font(.callout.weight(.medium))
                Text("Sharing will pause when your iPhone connects. You can leave this screen.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if person.isRemovingAccess && person.scopes.isEmpty {
                Label("Sharing paused", systemImage: "pause.circle")
                    .font(.callout.weight(.medium))
                Text("iCloud access removal is pending. Your iPhone will retry automatically.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if person.canPause {
                if store.failedPauses.contains(person.id) {
                    Text("Could not pause. Open Sharing on your iPhone or try again.")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Button("Pause sharing", systemImage: "pause.fill") { confirmsPause = true }
            } else {
                Text("Resume sharing on your iPhone.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .animation(reduceMotion ? nil : .smooth, value: isPending)
        .confirmationDialog("Pause sharing with \(person.name)?", isPresented: $confirmsPause, titleVisibility: .visible) {
            Button("Pause sharing", role: .destructive) {
                store.requestPause(for: person)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Stops sharing both ways when your iPhone connects. Resume on iPhone.")
        }
    }
}

private struct WatchSharingRing: View {
    let snapshot: CalorieCardSnapshot?
    let mode: GraphMode
    let hidesGoalStatus: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let values = mode == .midnight ? snapshot?.midnight ?? snapshot?.now : snapshot?.now
            CalorieCircleGraph(
                energy: values?.energy ?? EnergyBalance(active: 0, resting: 0, consumed: 0),
                configuration: .init(lineWidth: size * 0.09, ringSpacing: size * 0.025, segmentGap: size * 0.025),
                palette: .init(burned: snapshot?.appearance.burned.color(in: .dark) ?? .clear,
                               consumed: snapshot?.appearance.consumed.color(in: .dark) ?? .clear,
                               empty: snapshot?.appearance.graphEmpty.color(in: .dark) ?? Color(white: 0.28))
            )
            .overlay {
                if !hidesGoalStatus, let values, !values.energy.isEmpty, let reached = values.visibleGoalReached {
                    Image(systemName: reached ? "checkmark" : "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary).offset(y: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WatchSharingBalanceText: View {
    let values: CalorieCardSnapshot.ModeValues
    let unit: String

    var body: some View {
        Text("\(Text(abs(values.balance), format: .number)) \(unit) \(Text(values.balanceTitle).foregroundStyle(.secondary))")
            .monospacedDigit()
    }
}

private struct WatchSharingTimestamp: View {
    let date: Date
    let isMissing: Bool

    var body: some View {
        Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
            .font(.caption2)
            .foregroundStyle(isMissing ? Color.red : .secondary)
            .lineLimit(1)
    }
}

private extension CalorieCardSnapshot.ModeValues {
    var balanceTitle: LocalizedStringResource {
        balance == 0 ? "Balance" : balance > 0 ? "Deficit" : "Surplus"
    }
}

private extension WatchSharingSnapshot.Person {
    var status: LocalizedStringResource {
        if scopes.isEmpty { return "Sharing paused" }
        if !isReady { return "Connecting" }
        if scopes.contains(.today) { return "No update today" }
        if scopes.contains(.history) { return "No recent cards" }
        return "Goal status & streak"
    }
}
