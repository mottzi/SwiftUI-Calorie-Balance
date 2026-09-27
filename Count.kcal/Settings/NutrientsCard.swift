import SwiftUI

struct NutrientsCard: View {

    @EnvironmentObject private var AppSettings: Settings
        
    var body: some View {
        Card("Nutrients", titlePadding: false) {
            VStack(spacing: 12) {
                MacroSlider()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                
                HStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Text("Carbs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4) {
                            Text("\(AppSettings.carbsGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange.gradient)
                            
                            Text(verbatim: "g")
                                .font(.caption)
                                .fontWeight(.thin)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                        }
                    }
                    .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(spacing: 6) {
                        Text("Fats")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4) {
                            Text("\(AppSettings.fatsGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(red: 217/255, green: 220/255, blue: 214/255).gradient)
                            
                            Text(verbatim: "g")
                                .font(.caption)
                                .fontWeight(.thin)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                        }
                    }
                    .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(spacing: 6) {
                        Text("Protein")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4) {
                            Text("\(AppSettings.proteinGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red.gradient)
                            
                            Text(verbatim: "g")
                                .font(.caption)
                                .fontWeight(.thin)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                        }
                    }
                    .lineLimit(1)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 4)
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
