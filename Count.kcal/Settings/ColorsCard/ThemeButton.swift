import SwiftUI

struct ThemeButton: View
{
    @EnvironmentObject private var AppSettings: Settings

    var theme: Settings.Theme
    
    @State private var wasTapped: Bool = false
    
    var body: some View
    {
        VStack(spacing: 2)
        {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10)
                .fill(theme.burned)
                .frame(width: 60, height: 18)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 0)
                .fill(theme.consumed)
                .frame(width: 60, height: 18)
        }
        .scaleEffect(wasTapped ? 0.8 : 1.0)
        //.contentShape(.rect)
        .onTapGesture
        {
            AppSettings.burnedColor = theme.burned
            AppSettings.consumedColor = theme.consumed
            
            withAnimation(.spring(duration: 0.15))
            {
                wasTapped = true
            }
            completion:
            {
                withAnimation(.spring(duration: 0.15))
                {
                    wasTapped = false
                }
            }
        }
        .sensoryFeedback(.selection, trigger: AppSettings.burnedColor)
    }
}

