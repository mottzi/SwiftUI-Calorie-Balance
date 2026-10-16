/// Stable identities preserve each section's state when its position changes.
enum DashboardSection: String, Identifiable {
    case daily, progress

    var id: Self { self }
}
