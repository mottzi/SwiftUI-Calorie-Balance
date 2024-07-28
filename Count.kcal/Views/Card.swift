import SwiftUI

enum CardPickerType
{
    case none
    case balance
    case weight
}

enum CardLevel
{
    case clear
    case primary
}

extension Card where Subtitle == EmptyView
{
    init(_ title: LocalizedStringKey? = nil, level: CardLevel = .primary, secondaryTitle: String? = nil, titlePadding: Bool = true, innerPadding: CGFloat = 16, controls: CardPickerType = .none, @ViewBuilder content: @escaping () -> Content)
    {
        self.title = title
        self.secondaryTitle = secondaryTitle
        self.level = level
        self.titlePadding = titlePadding
        self.subtitle = nil
        self.innerPadding = innerPadding
        self.content = content
        self.controls = controls
    }
}

struct Card <Subtitle: View, Content: View>: View
{
    @EnvironmentObject private var AppSettings: Settings

    let title: LocalizedStringKey?
    let secondaryTitle: String?
    let titlePadding: Bool
    
    let innerPadding: CGFloat
    let controls: CardPickerType
    let level: CardLevel
    let subtitle: (() -> Subtitle)?
    let content: () -> Content
    
    let borderRadius: CGFloat = 10
    
    init(_ title: LocalizedStringKey? = nil, level: CardLevel = .primary, secondaryTitle: String? = nil, titlePadding: Bool = true, innerPadding: CGFloat = 16, controls: CardPickerType = .none, subtitle: (() -> Subtitle)? = nil, @ViewBuilder content: @escaping () -> Content)
    {
        self.title = title
        self.secondaryTitle = secondaryTitle
        self.level = level
        self.titlePadding = titlePadding
        self.subtitle = subtitle
        self.innerPadding = innerPadding
        self.content = content
        self.controls = controls
    }
    
    private func isContentEmpty(c: () -> Content) -> Bool
    {
        return Mirror(reflecting: c()).children.isEmpty
    }
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            if let title
            {
                HStack(spacing: 0)
                {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("TextColor"))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    
                    if let secondaryTitle
                    {
                        Spacer()
                        
                        Text(secondaryTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .fontDesign(.rounded)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .transaction { $0.animation = .none }
                    }
                }
                .padding(.leading, 4)
                .padding(.trailing, 8)
            }
            
            Group
            {
                if isContentEmpty(c: content)
                {
                    Color.gray.frame(height: 0).hidden()
                }
                else
                {
                    content()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(innerPadding)
            .background(background)
            .cornerRadius(borderRadius)
  
            if let subtitle
            {
                subtitle()
            }
        }
        .padding(.horizontal)
    }
    
    var background: Color
    {
        switch level 
        {
            case .clear:
                Color.clear
            case .primary:
                AppSettings.CardBackground
        }
    }
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
                .environment(Streak())
        }
    }
}
