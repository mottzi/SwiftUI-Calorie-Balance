import SwiftUI

/// Styled card with an optional title and secondary title.
struct Card<Content: View>: View {

    @EnvironmentObject private var settings: Settings

    private let title: LocalizedStringKey?
    private let secondaryTitle: String?
    private let innerPadding: CGFloat
    private let level: CardLevel
    private let content: Content

    init(
        _ title: LocalizedStringKey? = nil,
        level: CardLevel = .primary,
        secondaryTitle: String? = nil,
        innerPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.secondaryTitle = secondaryTitle
        self.level = level
        self.innerPadding = innerPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                CardHeader(title: title, secondaryTitle: secondaryTitle)
            }

            content
                .frame(maxWidth: .infinity)
                .padding(innerPadding)
                .background(level == .clear ? .clear : settings.CardBackground)
                .clipShape(.rect(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

}

/// Adapts the card's heading without observing content or settings changes.
private struct CardHeader: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    let title: LocalizedStringKey
    let secondaryTitle: String?

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            Text(title)
                .foregroundStyle(Color("TextColor"))

            if let secondaryTitle {
                if !dynamicType.isAccessibilitySize { Spacer() }
                Text(secondaryTitle.isEmpty ? " " : secondaryTitle)
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .transaction { $0.animation = nil }
                    .accessibilityHidden(secondaryTitle.isEmpty)
            }
        }
        .font(.subheadline.weight(.medium))
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .padding(.trailing, 8)
    }

}

enum CardLevel {

    case clear
    case primary

}

#Preview { PreviewPager }
