/// Keeps the selected mode and toolbar feedback in one parent-owned value.
struct TodayPageMode: Equatable {
    enum Control { case card, toolbar }

    private(set) var selection: PagerSelection
    private(set) var toolbarActivations = 0

    init(selection: PagerSelection = .first) {
        self.selection = selection
    }

    mutating func toggle(from control: Control) {
        selection.toggle()
        switch control {
        case .card: break
        case .toolbar: toolbarActivations += 1
        }
    }
}
