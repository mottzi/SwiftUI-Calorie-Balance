import SwiftUI

/// Presents progress content with a detent known before the opening animation.
struct ProgressSheetContent<Content: View>: View {

    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let detent: PresentationDetent
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                paddedContent
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    paddedContent
                }
                .scrollBounceBehavior(.basedOnSize)
                .softTopScrollEdge()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([detent])
        .presentationDragIndicator(.visible)
    }

    private var paddedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

}
