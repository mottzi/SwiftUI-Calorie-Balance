import SwiftUI

struct BalanceGoalView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HSlider.self) private var SliderData
    
    @State private var balanceSlider = 0.0
    
    var body: some View
    {
        VStack(spacing: 30)
        {
            TitleSegment
            ControllerSegment
            InfoSegment
        }
    }
    
    var TitleSegment: some View {
        (
            Text("What is your")
                .foregroundStyle(Color("TextColor").opacity(0.8))
                .fontWeight(.light)
            +
            Text(verbatim: " ")
            +
            Text((String(localized: AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")))
            +
            Text(verbatim: " ")
            +
            Text("goal")
                .foregroundStyle(Color("TextColor").opacity(0.8))
                .fontWeight(.light)
            +
            Text(verbatim: "?")
                .foregroundStyle(Color("TextColor").opacity(0.8))
                .fontWeight(.light)
        )
        .font(.title)
        .fontWeight(.semibold)
        .fontDesign(.rounded)
        .foregroundStyle(Color("TextColor").gradient)
    }
    
    var ControllerSegment: some View
    {
        VStack(spacing: 10)
        {
            HStack(alignment: .lastTextBaseline, spacing: 8)
            {
                Text("\(AppSettings.balanceGoal)")
                    .font(.title2)
                    .fontWeight(.semibold)
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
            
            Slider(value: $balanceSlider, in: 0...2000, step: 50)
                .onChange(of: balanceSlider)
            { _, n in
                AppSettings.balanceGoal = Int(n)
            }
            .onAppear
            {
                balanceSlider = Double(AppSettings.balanceGoal)
            }
            .tint(Color("ConsumedDefault"))
            .sensoryFeedback(.selection, trigger: balanceSlider)
        }
    }
    
    var InfoSegment: some View
    {
        Text("\(balanceGoalDescription)")
            .font(.headline)
            .foregroundStyle(Color("TextColor"))
            .fontWeight(.regular)
            .fontDesign(.rounded)
            .padding(.top, 25)
    }
    
    var balanceGoalDescription: String
    {
        switch AppSettings.weightGoal
        {
            case .lose:
                String(localized: "This deficit equates to a weight loss of \(weightChange7) per week or \(weightChange30) per month.")
            case .gain:
                String(localized: "This surplus equates to a weight gain of \(weightChange7) per week or \(weightChange30) per month.")
        }
    }
    
    var weightChange7: String
    {
        let unit = AppSettings.weightUnit
        let conversionFactor = unit == .kg ? 1.0 : 2.20462
        
        let weightChange = Double(AppSettings.balanceGoal) * 7 / 7700.0 * conversionFactor
        
        return String(format: "%.2f \(unit.rawValue)", weightChange)
    }
    
    var weightChange30: String
    {
        let unit = AppSettings.weightUnit
        let conversionFactor = unit == .kg ? 1.0 : 2.20462
        
        let weightChange = Double(AppSettings.balanceGoal) * 30 / 7700.0 * conversionFactor
        
        return String(format: "%.2f \(unit.rawValue)", weightChange)
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
