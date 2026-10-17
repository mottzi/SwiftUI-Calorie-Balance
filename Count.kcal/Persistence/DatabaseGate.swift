import SwiftUI
import Dependencies
import SQLiteData

/// Opens persistence before any database-backed view appears; failures preserve the saved file.
struct DatabaseGate<Content: View>: View {

    @State private var ready = false
    @State private var failed = false
    @State private var attempt = 0

    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if ready {
                content()
            } else if failed {
                ContentUnavailableView {
                    Label("Saved choices unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved choices could not be opened. Try again to continue.")
                } actions: {
                    Button("Try again") { attempt += 1 }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: attempt) {
            do {
                let database = try AppDatabase.open()
                prepareDependencies { $0.defaultDatabase = database }
                ready = true
            } catch {
                failed = true
            }
        }
    }

}
