import SwiftUI

struct ThemesSection: View 
{
    @EnvironmentObject private var AppSettings: Settings

//    @State private var showSuggestedThemes: Bool = false

    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack
            {
                Text("Themes")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()
//
//                Image(systemName: showSuggestedThemes == false ? "chevron.down" : "chevron.up")
//                    .frame(width: 20, height: 20)
//                    .font(.system(size: 16))
//                    .fontWeight(.bold)
//                    .foregroundStyle(Color("TextColor"))
//                    .brightness(0.1)
//                    .contentTransition(.symbolEffect(.replace, options: .speed(3)))
//                    .padding(.trailing, 4)
                    
            }
            .padding(.vertical, 6)
//            .contentShape(.rect)
//            .onTapGesture
//            {
//                withAnimation
//                {
//                    showSuggestedThemes.toggle()
//                }
//            }

//            if showSuggestedThemes
//            {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20)
                {
                    ForEach(Settings.Themes)
                    { theme in
                        ThemeButton(theme: theme)
                    }
                }
                .transition(.move(edge: .trailing))
                .saturation(Settings.baseSaturation)
                .brightness(level: .primary)
                .padding()
//            }
        }
    }
}

#Preview
{
    NavigationView
    {
        SettingsPage()
            .environmentObject(Settings.shared)
    }
}
