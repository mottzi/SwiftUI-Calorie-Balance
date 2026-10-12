import SwiftUI

/// Keeps card geometry while withholding unresolved measurements and their actions.
struct HealthLoadingPlaceholder: ViewModifier {

    @State private var showsProgress = false

    let isLoading: Bool
    let label: LocalizedStringKey
    var showsProgressIndicator = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .disabled(isLoading)
            .accessibilityHidden(isLoading)
            .overlay {
                if isLoading {
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(Text(label))
                        .allowsHitTesting(false)

                    if showsProgress {
                        ProgressView()
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
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
