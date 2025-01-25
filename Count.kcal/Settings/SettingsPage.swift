import SwiftUI
import WidgetKit

enum Field: Int, CaseIterable
{
    case balance, carbs, fats, protein, passive, active, steps
}

struct SettingsPage: View
{
    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.colorScheme) private var scheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) var scenePhase
    @FocusState private var focusedField: Field?

    @Environment(HSlider.self) private var SliderData
    // @State private var SliderData = HSlider()
    
    var body: some View
    {
        ZStack
        {
            AppSettings.AppBackground.ignoresSafeArea(.all)
            
            ScrollView
            {
                EnergySettingsView(focusedField: _focusedField)
                    .padding(.bottom, 20)

                VStack(spacing: 30)
                {
                    NutrientsCard()
                    StepsCard(focusedField: _focusedField)
                    UnitsCard()
                    ColorsCard()
                }
                
                VStack(spacing: 2)
                {
                    HStack(spacing: 6)
                    {
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 42))
                            .fontWeight(.black)
                            .foregroundStyle(LinearGradient(colors: [Color("TextColor"), Color("TextColor").opacity(0.5)], startPoint: .top, endPoint: .bottom))

                        Button
                        {
                            if let url = URL(string: "https://apps.apple.com/us/app/count-kcal/id6476797015?action=write-review"),
                               UIApplication.shared.canOpenURL(url)
                            {
                                UIApplication.shared.open(url)
                            }
                        }
                        label:
                        {
                            VStack(spacing: 4)
                            {
                                HStack(spacing: 4)
                                {
                                    Text("Rate us on the")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color("TextColor").opacity(0.9))

                                    Text(verbatim: "App Store")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color("TextColor"))
                                        .underline()
                                        .shadow(color: Color("TextColor").opacity(0.4), radius: 10, y: -2)
                                }

                                HStack()
                                {
                                    ForEach(1...5, id: \.self)
                                    { i in
                                        Image(systemName: "star.fill")
                                            .font(.subheadline)
                                            .fontWeight(.black)
                                            .foregroundStyle(.yellow.opacity(0.9).gradient)
                                    }
                                    
                                    Text(verbatim: "5 / 5")
                                        .font(.caption)
                                        .fontWeight(.light)
                                        .opacity(0.7)
                                        .offset(x: -2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Image(systemName: "laurel.trailing")
                            .font(.system(size: 42))
                            .fontWeight(.black)
                            .foregroundStyle(LinearGradient(colors: [Color("TextColor"), Color("TextColor").opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    }
                    .padding(.top, 10)
                    .foregroundStyle(Color("TextColor"))
                    
                    Divider()
                        .frame(width: 190)
                        .padding(.vertical, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                
                    HStack(spacing: 24)
                    {
                        Button
                        {
                            if let url = URL(string: "twitter://user?screen_name=BerkenSayilir"),
                               UIApplication.shared.canOpenURL(url)
                            {
                                UIApplication.shared.open(url)
                            }
                        }
                        label:
                        {
                            HStack(spacing: 3)
                            {
                                Text("Contact")
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryTextColor"))
                                    .fontWeight(.medium)
                                    .padding(.trailing, 4)
                                
                                Image(systemName: "bubble")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(Color("TextColor"))
                                    .frame(height: 14)
                                    .fontWeight(.medium)
                                    .offset(y: 1)
                                
                                Image(scheme == .dark ? "XAppWhite" : "XAppBlack")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 18)
                                    .opacity(0.9)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button
                        {
                            if let url = URL(string: "https://count.mottzi.de/help"),
                               UIApplication.shared.canOpenURL(url)
                            {
                                UIApplication.shared.open(url)
                            }
                        }
                        label:
                        {
                            HStack(spacing: 3)
                            {
                                Text("Support")
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryTextColor"))
                                    .fontWeight(.medium)
                                
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(Color("TextColor"))
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom)
                }
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.large)
            .sendContextOnChange(of: AppSettings.customCalActive)
            .sendContextOnChange(of: AppSettings.customCalPassive)
            .sendContextOnChange(of: AppSettings.balanceGoal)
            .sendContextOnChange(of: AppSettings.carbsGoal)
            .sendContextOnChange(of: AppSettings.fatsGoal)
            .sendContextOnChange(of: AppSettings.proteinGoal)
            .sendContextOnChange(of: AppSettings.weightGoal)
            .sendContextOnChange(of: AppSettings.dataSource)
            .sendContextOnChange(of: AppSettings.consumedColor)
            .sendContextOnChange(of: AppSettings.burnedColor)
            .toolbar
            {
                ToolbarItem(placement: .keyboard)
                {
                    Button("Done")
                    {
                        focusedField = nil
                    }
                    .foregroundStyle(Color("TextColor"))
                }
                
                ToolbarItem(placement: .topBarLeading)
                {
                    Button 
                    {
                        WidgetCenter.shared.reloadAllTimelines()
                                                
                        dismiss()
                    }
                    label:
                    {
                        HStack
                        {
                            Image(systemName: "chevron.left")
                                .font(.callout)
                                
                            Text("Back")
                        }
                        .foregroundColor(Color("TextColor"))
                        .fontWeight(.semibold)
                    }
                    .padding(.leading, 16)
                }
                
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing)
                {
                    Button
                    {
                        AppSettings.showWelcome = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
                        {
                            dismiss()
                        }
                    }
                    label:
                    {
                        Text(verbatim: "Setup")
                            .foregroundColor(Color("TextColor"))
                            .fontWeight(.semibold)
                    }
                    .padding(.trailing, 24)
                }
                #endif
            }
        }
    }
}

#Preview
{
    NavigationView
    {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
