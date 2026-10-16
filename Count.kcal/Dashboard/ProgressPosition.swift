import Foundation

enum ProgressPosition: String, CaseIterable, Identifiable {
    case above, below

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .above: "Above daily cards"
        case .below: "Below daily cards"
        }
    }

    var sections: [DashboardSection] {
        switch self {
        case .above: [.progress, .daily]
        case .below: [.daily, .progress]
        }
    }
}

extension Settings {
    var dashboardProgressPosition: ProgressPosition {
        get { ProgressPosition(rawValue: progressPosition) ?? .below }
        set { progressPosition = newValue.rawValue }
    }
}
