import SwiftUI

struct BackgroundColorSection: View
{
    @EnvironmentObject private var AppSettings: Settings
    
    var body: some View
    {
        HStack(alignment: .top)
        {
            Text("Background")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 24)
            {
                VStack(spacing: 8)
                {
                    ZStack
                    {
                        Circle()
                            .stroke(Color(white: AppSettings.appBackground == .black ? 0.7 : 0.22), lineWidth: 6)
                            .fill(.black)
                            .frame(width: 24, height: 24)
                        
                        if AppSettings.appBackground == .black
                        {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.black)
                        }
                    }
                    
                    Text("Black")
                        .font(.caption)
                        .foregroundStyle(Color("TextColor"))
                        .opacity(AppSettings.appBackground == .black ? 1 : 0.6)
                }
                .contentShape(.rect)
                .onTapGesture
                {
                    withAnimation
                    {
                        AppSettings.appBackground = .black
                    }
                }
                .padding(.leading, -15)
                
                
                VStack(spacing: 8)
                {
                    ZStack
                    {
                        Circle()
                            .stroke(Color(white: AppSettings.appBackground == .dark ? 0.7 : 0.22), lineWidth: 6)
                            .fill(Color("BackGroundColor"))
                            .frame(width: 24, height: 24)
                        
                        if AppSettings.appBackground == .dark
                        {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.black)
                        }
                    }
                    
                    Text("Dark")
                        .font(.caption)
                        .foregroundStyle(Color("TextColor"))
                        .opacity(AppSettings.appBackground == .dark ? 1 : 0.6)
                }
                .contentShape(.rect)
                .onTapGesture
                {
                    withAnimation
                    {
                        AppSettings.appBackground = .dark
                    }
                }
                
                VStack(spacing: 8)
                {
                    ZStack
                    {
                        Circle()
                            .stroke(Color(white: AppSettings.appBackground == .light ? 0.7 : 0.22), lineWidth: 6)
                            .fill(Color(white: 0.1))
                            .frame(width: 24, height: 24)
                        
                        if AppSettings.appBackground == .light
                        {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.black)
                        }
                    }
                    
                    Text("Gray")
                        .font(.caption)
                        .foregroundStyle(Color("TextColor"))
                        .opacity(AppSettings.appBackground == .light ? 1 : 0.6)
                }
                .contentShape(.rect)
                .onTapGesture
                {
                    withAnimation
                    {
                        AppSettings.appBackground = .light
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: AppSettings.appBackground)
        }
        .padding(.top, 6)
        
        Divider()
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
