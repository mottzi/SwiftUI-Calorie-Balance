import SwiftUI

struct NutrientsCard: View
{
    @Environment(HSlider.self) private var SliderData
    @EnvironmentObject private var AppSettings: Settings
    
    @FocusState var focusedField: Field?
    
    var body: some View
    {
        Card("Nutrients", titlePadding: false)
        {
            VStack(spacing: 12)
            {
                MacroSlider()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                
//                HStack(alignment: .lastTextBaseline)
//                {
//                    Text("Carbs")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .frame(minWidth: 70, alignment: .leading)
//
//                    Spacer()
//                    
//                    IconPicker(firstIcon: "chevron.right", secondIcon: "chevron.left", iconFontSize: 12, style: .capsule, exclusiveLabel: true, selection: $AppSettings.carbsReversedGoal)
//                        .frame(width: 60, height: 30)
//                        .offset(y: 10)
//                        .padding(.trailing, 4)
//                        .sensoryFeedback(.selection, trigger: AppSettings.carbsReversedGoal)
//                    
//                    Text("\(AppSettings.carbsGoal)")
//                        .multilineTextAlignment(.trailing)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundStyle(Color("TextColor"))
//                        .offset(x: 3)
//                        .frame(minWidth: 30)
//                        .frame(maxWidth: 80)
//                        .fixedSize()
//                    
//                    Text(verbatim: "g")
//                        .font(.caption)
//                        .fontWeight(.thin)
//                        .fontDesign(.rounded)
//                        .foregroundStyle(Color("TextColor"))
//                        .frame(minWidth: 22, alignment: .leading)
//                }
//
//                Divider()
//                    .offset(y: 8)
//                
//                HStack(alignment: .lastTextBaseline)
//                {
//                    Text("Fats")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .frame(minWidth: 70, alignment: .leading)
//                    
//                    Spacer()
//                    
//                    IconPicker(firstIcon: "chevron.right", secondIcon: "chevron.left", iconFontSize: 12, style: .capsule, exclusiveLabel: true, selection: $AppSettings.fatsReversedGoal)
//                        .frame(width: 60, height: 30)
//                        .offset(y: 10)
//                        .padding(.trailing, 4)
//                        .sensoryFeedback(.selection, trigger: AppSettings.fatsReversedGoal)
//                    
//                    Text("\(AppSettings.fatsGoal)")
//                        .multilineTextAlignment(.trailing)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundStyle(Color("TextColor"))
//                        .offset(x: 3)
//                        .frame(minWidth: 30)
//                        .frame(maxWidth: 80)
//                        .fixedSize()
//                    
//                    Text(verbatim: "g")
//                        .font(.caption)
//                        .fontWeight(.thin)
//                        .fontDesign(.rounded)
//                        .foregroundStyle(Color("TextColor"))
//                        .frame(minWidth: 22, alignment: .leading)
//                }
//
//                
//                Divider()
//                    .offset(y: 8)
//                
//                HStack(alignment: .lastTextBaseline)
//                {
//                    Text("Protein")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .frame(minWidth: 70, alignment: .leading)
//                    
//                    Spacer()
//                    
//                    IconPicker(firstIcon: "chevron.right", secondIcon: "chevron.left", iconFontSize: 12, style: .capsule, exclusiveLabel: true, selection: $AppSettings.proteinReversedGoal)
//                        .frame(width: 60, height: 30)
//                        .offset(y: 10)
//                        .padding(.trailing, 4)
//                        .sensoryFeedback(.selection, trigger: AppSettings.proteinReversedGoal)
//                    
//                    Text("\(AppSettings.proteinGoal)")
//                        .multilineTextAlignment(.trailing)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundStyle(Color("TextColor"))
//                        .offset(x: 3)
//                        .frame(minWidth: 30)
//                        .frame(maxWidth: 80)
//                        .fixedSize()
//
//                    Text(verbatim: "g")
//                        .font(.caption)
//                        .fontWeight(.thin)
//                        .fontDesign(.rounded)
//                        .foregroundStyle(Color("TextColor"))
//                        .frame(minWidth: 22, alignment: .leading)
//                }
//                .padding(.bottom, 8)
                
                HStack(spacing: 12)
                {
                    VStack(spacing: 6)
                    {
                        Text("Carbs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4)
                        {
                            Text("\(AppSettings.carbsGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange.gradient)
//                                .contentTransition(.numericText(value: Double(AppSettings.carbsGoal)))
//                                .animation(.easeOut, value: AppSettings.carbsGoal)
                            
                            Text(verbatim: "g")
                                .font(.caption)
                                .fontWeight(.thin)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                        }
                    }
                    .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(spacing: 6)
                    {
                        Text("Fats")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4)
                        {
                            Text("\(AppSettings.fatsGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(red: 217/255, green: 220/255, blue: 214/255).gradient)
//                                .contentTransition(.numericText(value: Double(AppSettings.fatsGoal)))
//                                .animation(.easeOut, value: AppSettings.fatsGoal)
                            
                            Text(verbatim: "g")
                                .font(.caption)
                                .fontWeight(.thin)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                        }
                    }
                    .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(spacing: 6)
                    {
                        Text("Protein")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize()

                        HStack(spacing: 4)
                        {
                            Text("\(AppSettings.proteinGoal)")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red.gradient)
//                                .contentTransition(.numericText(value: Double(AppSettings.proteinGoal)))
//                                .animation(.easeOut, value: AppSettings.proteinGoal)
                            
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

#Preview
{
    NavigationView
    {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
