import SwiftUI

/// Gives unresolved card content loading semantics without changing its appearance.
struct HealthLoadingPlaceholder: ViewModifier {

    @State private var showsProgress = false

    let isLoading: Bool
    let label: LocalizedStringKey
    var showsProgressIndicator = false

    func body(content: Content) -> some View {
        content
            .disabled(isLoading)
            .accessibilityHidden(isLoading)
            .overlay(alignment: .topTrailing) {
                if isLoading {
                    ZStack(alignment: .topTrailing) {
                        Color.clear
                            .accessibilityElement()
                            .accessibilityLabel(Text(label))

                        if showsProgress {
                            ProgressView()
                                .controlSize(.small)
                                .padding(12)
                                .accessibilityHidden(true)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .task(id: isLoading && showsProgressIndicator) {
                showsProgress = false
                guard isLoading && showsProgressIndicator else { return }
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard !Task.isCancelled else { return }
                showsProgress = true
            }
    }

}
