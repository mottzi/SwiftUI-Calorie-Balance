import SwiftUI

struct DataSourceView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HSlider.self) private var SliderData
    @Environment(\.colorScheme) private var scheme: ColorScheme
    
    @State private var activeSlider = 0.0
    @State private var passiveSlider = 0.0
    
    var body: some View
    {
        VStack(spacing: 30)
        {
            VStack(spacing: 30)
            {
                (
                    Text("For")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                    +
                    Text(verbatim: " ")
                    +
                    Text("burned calories")
                    +
                    Text(", use ...")
                        .foregroundStyle(Color("TextColor").opacity(0.8))
                        .fontWeight(.light)
                )
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor").gradient)
                
                IconPicker(firstIcon: "heart.fill", secondIcon: "pencil.and.list.clipboard", selection: $AppSettings.dataSource.animation(.bouncy))
                    .frame(width: 120, height: 40)
                    .scaleEffect(1.4)
                    .sensoryFeedback(.selection, trigger: AppSettings.dataSource)
                
                Text(AppSettings.dataSource == .apple ? String("Apple Health") : String(localized: "Custom Data"))
                    .font(.title)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .animation(.linear, value: AppSettings.dataSource)
                    .foregroundStyle(Color("TextColor"))
            }
            
            if AppSettings.dataSource == .custom
            {
                VStack(spacing: 20)
                {
                    VStack(spacing: 10)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 8)
                        {
                            Text("Resting Calories")
                                .foregroundStyle(Color("TextColor"))
                            
                            if !AppSettings.isPassiveValid
                            {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.red.gradient)
                                    .offset(y: -1)
                            }
                            
                            Spacer()
                            
                            Text("\(AppSettings.customCalPassive)")
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                                .fixedSize()
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.callout)
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Slider(value: $passiveSlider, in: 1000...4000, step: 50)
                            .onChange(of: passiveSlider)
                        { _, n in
                            AppSettings.customCalPassive = Int(n)
                        }
                        .onAppear
                        {
                            passiveSlider = Double(AppSettings.customCalPassive)
                        }
                        .sensoryFeedback(.selection, trigger: passiveSlider)
                    }
                    
                    VStack(spacing: 10)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 8)
                        {
                            Text("Active Calories")
                                .foregroundStyle(Color("TextColor"))
                            
                            if !AppSettings.isActiveValid
                            {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.red.gradient)
                                    .offset(y: -1)
                            }
                            
                            Spacer()
                            
                            Text("\(AppSettings.customCalActive)")
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                                .fixedSize()
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.callout)
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("TextColor"))
                                .opacity(0.8)
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Slider(value: $activeSlider, in: 100...2000, step: 50)
                            .onChange(of: activeSlider)
                        { _, n in
                            AppSettings.customCalActive = Int(n)
                        }
                        .onAppear
                        {
                            activeSlider = Double(AppSettings.customCalActive)
                        }
                        .sensoryFeedback(.selection, trigger: activeSlider)
                    }
                }
                .geometryGroup()
                .transition(.slide.combined(with: .opacity))
                .animation(.snappy, value: AppSettings.dataSource)
            }
        }
    }
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightDataViewModel())
    .environment(Streak())
}
