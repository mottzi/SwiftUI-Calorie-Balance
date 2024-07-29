import SwiftUI

struct EnergySettingsView: View
{
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings
    
    @FocusState var focusedField: Field?
    
//    @State private var showResting: Int = 0
//    @State private var showActive: Int = 0
    
    @Environment(HSlider.self) private var SliderData
        
    var body: some View
    {
        VStack(spacing: 22)
        {
            HStack(alignment: .bottom)
            {
                Spacer()
                
                VStack(spacing: 12)
                {
                    Text("I want to...")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                    
                    IconPicker(firstIcon: "arrowshape.down.fill", secondIcon: "arrowshape.up.fill", selection: $AppSettings.weightGoal)
                        .frame(width: 100, height: 35)
                        .sensoryFeedback(.selection, trigger: AppSettings.weightGoal)

                    
                    Text(AppSettings.weightGoal == .lose ? "Lose Weight" : "Gain Weight")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .animation(.linear, value: AppSettings.weightGoal)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                        
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            .shadow(.inner(color: scheme == .dark ? Color(white: 0.5).opacity(0.2) : Color(red: 197/255, green: 197/255, blue: 197/255).opacity(0.5), radius: 2, x:2, y: 2))
                            .shadow(.inner(color: scheme == .dark ? Color(white: 0.2).opacity(0.2) : Color.white, radius: 2, x: -2, y: -2))
                        )
                        .foregroundColor(AppSettings.CardBackground)
                )
                .shadow(color: Color(white: scheme == .light ? 0.8 : 0).opacity(scheme == .light ? 0.2 : 0), radius: 4, x: 0, y: 4)

                Spacer()
                
                VStack(spacing: 12)
                {
                    Text("For burned calories, use...")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                        .frame(width: 100)
                    
                    IconPicker(firstIcon: "heart.fill", secondIcon: "pencil.and.list.clipboard", selection: $AppSettings.dataSource)
                        .frame(width: 100, height: 35)
                        .sensoryFeedback(.selection, trigger: AppSettings.dataSource)
                    
                    Text(AppSettings.dataSource == .apple ? String("Apple Health") : String(localized: "Custom Data"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .animation(.linear, value: AppSettings.dataSource)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                    
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            .shadow(.inner(color: scheme == .dark ? Color(white: 0.5).opacity(0.2) : Color(red: 197/255, green: 197/255, blue: 197/255).opacity(0.5), radius: 2, x:2, y: 2))
                            .shadow(.inner(color: scheme == .dark ? Color(white: 0.2).opacity(0.2) : Color.white, radius: 2, x: -2, y: -2))
                        )
                        .foregroundColor(AppSettings.CardBackground)
                )
                .shadow(color: Color(white: scheme == .light ? 0.8 : 0).opacity(scheme == .light ? 0.2 : 0), radius: 4, x: 0, y: 4)

                Spacer()
            }
                        
            VStack(spacing: 12)
            {
                HStack(alignment: .lastTextBaseline)
                {
                    HStack(spacing: 8)
                    {
                        Text("Resting Calories")
                            .foregroundStyle(Color("TextColor"))
                        
                        if !AppSettings.isPassiveValid
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize()

                    Spacer()
                    
                    HStack(alignment: .lastTextBaseline)
                    {
                        if AppSettings.dataSource == .custom
                        {
                            TextField(String("0"), value: $AppSettings.customCalPassive, format: .number)
                                .focused($focusedField, equals: .active)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextColor"))
                                .offset(x: 3)
                                .underline()
                                .onChange(of: AppSettings.customCalPassive)
                                {
                                    AppSettings.customCalPassive = abs(AppSettings.customCalPassive)
                                    
                                    Task { await SliderData.updateMacroWeights() }
                                }
                        }
                        else
                        {
                            Text("\(AppSettings.showResting)")
                                .frame(width: 50, alignment: .trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextColor"))
                                .offset(x: 3)
                                .opacity(0.6)
                        }
                        
                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.caption)
                            .fontWeight(.thin)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .padding(.leading, 4)
                    }
                }
                .frame(height: 20)
                .padding(.top, 6)
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

                HStack(alignment: .lastTextBaseline)
                {
                    HStack(spacing: 8)
                    {
                        Text("Active Calories")
                            .foregroundStyle(Color("TextColor"))
                        
                        if !AppSettings.isActiveValid
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize()
                    
                    Spacer()
                    
                    HStack(alignment: .lastTextBaseline)
                    {
                        if AppSettings.dataSource == .custom
                        {
                            TextField(String("0"), value: $AppSettings.customCalActive, format: .number)
                                .focused($focusedField, equals: .active)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(.trailing)
//                                .frame(width: 50, height: 20)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextColor"))
                                .offset(x: 3)
                                .underline()
                                .onChange(of: AppSettings.customCalActive)
                                {
                                    AppSettings.customCalActive = abs(AppSettings.customCalActive)
                                    
                                    Task { await SliderData.updateMacroWeights() }
                                }
//                                .onSubmit { Connectivity.shared.sendSettingsContext() }
                        }
                        else
                        {
                            Text("\(AppSettings.showActive)")
                                .frame(width: 50, alignment: .trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextColor"))
                                .offset(x: 3)
                                .opacity(0.6)
                        }

                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.caption)
                            .fontWeight(.thin)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .padding(.leading, 4)
                    }
                }
                .frame(height: 20)
                .padding(.horizontal, 15)
                
                HStack(alignment: .lastTextBaseline)
                {
                    HStack(spacing: 8)
                    {
                        Text("Total Burned")
                            .foregroundStyle(Color("TextColor"))
                        
                        if !AppSettings.isBurnedValid
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize()
                    
                    Spacer()
                    
                    HStack(alignment: .lastTextBaseline)
                    {
                        Text("\(AppSettings.dataSource == .apple ? (AppSettings.showActive + AppSettings.showResting) : (AppSettings.customCalActive + AppSettings.customCalPassive))")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: 3)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                        
                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.caption)
                            .fontWeight(.thin)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .padding(.leading, 4)
                    }
                }
                .frame(height: 20)
//                .padding(.bottom, 6)
                .background
                {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(AppSettings.AppBackground)
                        .stroke(Color("SecondaryTextColor").opacity(0.05), style: StrokeStyle(lineWidth: 0.5))
                        .padding(-10)
                        .padding(.horizontal, -5)
                        .shadow(color: Color(white: scheme == .light ? 0.8 : 0.2).opacity(scheme == .dark ? 0 : 0.1), radius: 4, x: 0, y: 4)
                }
                .padding(10)
                .padding(.horizontal, 5)
                .offset(y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        .shadow(.inner(color: scheme == .dark ? Color(white: 0.5).opacity(0.2) : Color(red: 197/255, green: 197/255, blue: 197/255).opacity(0.5), radius: 2, x:2, y: 2))
                        .shadow(.inner(color: scheme == .dark ? Color(white: 0.2).opacity(0.2) : Color.white, radius: 2, x: -2, y: -2))
                    )
                    .foregroundColor(AppSettings.CardBackground)
            )
            .shadow(color: Color(white: scheme == .light ? 0.8 : 0).opacity(scheme == .light ? 0.2 : 0), radius: 4, x: 0, y: 4)
            .overlay(alignment: .topLeading)
            {
                ZStack
                {
                    Circle()
                        .fill(Color(white: scheme == .dark ? 0.2 : 1).gradient)
                        .shadow(color: .init(white: 0.1).opacity(0.2), radius: 1, x: 2, y: 2)
                        .frame(width: 30)
                              
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15))
                        .fontWeight(.bold)                        
                        .foregroundStyle(AppSettings.burnedColor)
                        .brightness(level: scheme == .dark ? .secondary : .none)
                }
                .offset(x: -4, y: -4)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .animation(.snappy, value: AppSettings.dataSource)
            
            VStack(spacing: 12)
            {
                HStack(alignment: .lastTextBaseline)
                {
                    Text(AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .animation(.default, value: AppSettings.weightGoal)
                        .fixedSize()
                    
                    Spacer()
                    
                    HStack(alignment: .lastTextBaseline)
                    {
                        TextField(String("0"), value: $AppSettings.balanceGoal, format: .number)
                            .focused($focusedField, equals: .balance)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .offset(x: 3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .underline()
                            .onChange(of: AppSettings.balanceGoal)
                            { /*o, n in*/
                                AppSettings.balanceGoal = abs(AppSettings.balanceGoal)

                                Task { await SliderData.updateMacroWeights() }
                            }
                    
                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.caption)
                            .fontWeight(.thin)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 15)

                
                HStack(alignment: .lastTextBaseline)
                {
                    HStack(alignment: .center, spacing: 8)
                    {
                        Text("Eating goal")
                            .foregroundStyle(Color("TextColor"))
                        
                        if AppSettings.maxEatingEnergy() <= 0
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(alignment: .lastTextBaseline)
                    {
                        Text("\(AppSettings.maxEatingEnergy())")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .offset(x: 3)

                        Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                            .font(.caption)
                            .fontWeight(.thin)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("TextColor"))
                            .padding(.leading, 4)
                    }
                }
                .frame(height: 20)
                .background
                {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(AppSettings.AppBackground)
                        .stroke(Color("SecondaryTextColor").opacity(0.05), style: StrokeStyle(lineWidth: 0.5))
                        .padding(-10)
                        .padding(.horizontal, -5)
                        .shadow(color: Color(white: scheme == .light ? 0.8 : 0.2).opacity(scheme == .dark ? 0 : 0.1), radius: 4, x: 0, y: 4)
                }
                .padding(10)
                .padding(.horizontal, 5)
                .offset(y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        .shadow(.inner(color: scheme == .dark ? Color(white: 0.5).opacity(0.2) : Color(red: 197/255, green: 197/255, blue: 197/255).opacity(0.5), radius: 2, x:2, y: 2))
                        .shadow(.inner(color: scheme == .dark ? Color(white: 0.2).opacity(0.2) : Color.white, radius: 2, x: -2, y: -2))
                    )
                    .foregroundColor(AppSettings.CardBackground)
            )
            .shadow(color: Color(white: scheme == .light ? 0.8 : 0).opacity(scheme == .light ? 0.2 : 0), radius: 4, x: 0, y: 4)
            .overlay(alignment: .topLeading)
            {
                ZStack
                {
                    Circle()
                        .fill(Color(white: scheme == .dark ? 0.2 : 1).gradient)
                        .shadow(color: .init(white: 0.1).opacity(0.2), radius: 1, x: 2, y: 2)
                        .frame(width: 30)
                              
                    Image(systemName: "fork.knife")
                        .font(.system(size: 13))
                        .fontWeight(.bold)                        
                        .foregroundStyle(AppSettings.consumedColor)
                        .brightness(level: scheme == .dark ? .secondary : .none)
                }
                .offset(x: -4, y: -4)
            }
            .padding(.horizontal, 40)
            .animation(.snappy, value: AppSettings.dataSource)
        }
//        .task
//        {
//            await AppSettings.updateShow()
//        }
        .onAppear
        {
            Task
            {
                await AppSettings.updateShow()
            }
        }
        .onChange(of: AppSettings.dataSource)
        {
            Task 
            {
                await AppSettings.updateShow()
            }
        }
        .onChange(of: AppSettings.energyUnit) 
        {
            Task
            {
                await AppSettings.updateShow()
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
