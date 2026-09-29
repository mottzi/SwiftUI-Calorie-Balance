import SwiftUI

struct NutrientsCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings
        
    var body: some View {
        Card("Nutrients", titlePadding: false) {
            VStack(spacing: 12) {
                MacroSlider()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))) {
                    VStack(spacing: 6) {
                        Text("Carbs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)

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
                        if dynamicType.isAccessibilitySize {
                            Text(AppSettings.carbsRatio, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryTextColor"))
                        }
                    }
                    .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    VStack(spacing: 6) {
                        Text("Fats")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)

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
                        if dynamicType.isAccessibilitySize {
                            Text(AppSettings.fatsRatio, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryTextColor"))
                        }
                    }
                    .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    VStack(spacing: 6) {
                        Text("Protein")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)

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
                        if dynamicType.isAccessibilitySize {
                            Text(AppSettings.proteinRatio, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryTextColor"))
                        }
                    }
                    .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
