import SwiftUI

@Observable class HSlider
{
    var carbsWidthLast: CGFloat = 0
    var fatsWidthLast: CGFloat = 0
    var protsWidthLast: CGFloat = 0
    
    var carbsWidth: CGFloat = 0
    var fatsWidth: CGFloat = 0
    var protsWidth: CGFloat = 0
    
    var minSegmentRatio: CGFloat = 0.1
    var maxSegmentRatio: CGFloat { 1 - minSegmentRatio - minSegmentRatio }
    
    var snapTo = 0.05
    
    @MainActor
    func updateMacroWeights() async
    {
        var maxEnergy = 0

        if Settings.shared.dataSource == .apple
        {
            Settings.shared.showResting = await HKRepository.shared.cumDataWeek(fetch: .basalEnergyBurned, for: .now)
            Settings.shared.showActive = await HKRepository.shared.cumDataWeek(fetch: .activeEnergyBurned, for: .now)
        }
        
        maxEnergy = Settings.shared.maxEatingEnergy()


        Settings.shared.carbsGoal = ratioToWeight(maxEatingEnergy: maxEnergy, ratio: Settings.shared.carbsRatio, type: .carbohydrates)
        Settings.shared.fatsGoal = ratioToWeight(maxEatingEnergy: maxEnergy, ratio: Settings.shared.fatsRatio, type: .fats)
        Settings.shared.proteinGoal = ratioToWeight(maxEatingEnergy: maxEnergy, ratio: Settings.shared.proteinRatio, type: .proteins)
    }
    
    func ratioToWidth(_ maxSlider: CGFloat)
    {
        let minSegment = maxSlider * minSegmentRatio

        if Settings.shared.carbsRatio * maxSlider < minSegment
            || Settings.shared.fatsRatio * maxSlider < minSegment
            || Settings.shared.proteinRatio * maxSlider < minSegment
        {
            Settings.shared.carbsRatio = 0.4
            Settings.shared.fatsRatio = 0.35
            Settings.shared.proteinRatio = 0.25
        }
        
        carbsWidth = maxSlider * Settings.shared.carbsRatio
        carbsWidthLast = carbsWidth
        
        fatsWidth = maxSlider * Settings.shared.fatsRatio
        fatsWidthLast = fatsWidth
        
        protsWidth = maxSlider * Settings.shared.proteinRatio
        protsWidthLast = protsWidth
    }
    
    func widthToRatio(_ maxSlider: CGFloat)
    {
        Settings.shared.carbsRatio = carbsWidth / maxSlider
        Settings.shared.fatsRatio = fatsWidth / maxSlider
        Settings.shared.proteinRatio = protsWidth / maxSlider
    }
    
    func ratioToWeight(maxEatingEnergy: Int, ratio: Double, type: MacroType) -> Int
    {
        var energyDensity: Double
        
        switch type
        {
            case .carbohydrates:
                energyDensity = 4
            case .fats:
                energyDensity = 9
            case .proteins:
                energyDensity = 4
        }
        
        energyDensity = Settings.shared.energyUnit == .kcal ? energyDensity : energyDensity * 4.184
        
        return Int((Double(maxEatingEnergy) * ratio / Double(energyDensity)).rounded())
    }
}

enum MacroType
{
    case carbohydrates
    case fats
    case proteins
}

struct MacroSlider: View
{
    @EnvironmentObject private var AppSettings: Settings
    
    @Environment(HSlider.self) private var SliderData
    
    var body: some View
    {
        GeometryReader
        { geo in
            let maxSlider = geo.size.width
            
            ZStack(alignment: .leading)
            {
                // Carbs slider segment
                Rectangle()
                    .fill(.orange.gradient)
                    .frame(width: SliderData.carbsWidth)
                    .overlay(alignment: .topLeading)
                    {
                        Text("\(String(format: "%.0f", SliderData.carbsWidth / maxSlider * 100))\(SliderData.carbsWidth / maxSlider <= 0.11 ? "" : "%")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9))
                            .offset(x: 6, y: 4)
                    }
                
                // Fats slider segment
                Rectangle()
                    .fill(Color(red: 217/255, green: 220/255, blue: 214/255).gradient)
                    .frame(width: SliderData.fatsWidth)
                    .overlay(alignment: .topLeading)
                    {
                        Text("\(String(format: "%.0f", SliderData.fatsWidth / maxSlider * 100))\(SliderData.fatsWidth / maxSlider <= 0.11 ? "" : "%")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9))
                            .offset(x: 6, y: 4)
                    }
                    .offset(x: SliderData.carbsWidth)
                    .sensoryFeedback(trigger: SliderData.fatsWidth) { o, n in return o != 0 ? .selection : nil }
                
                // Prots slider segment
                Rectangle()
                    .fill(.red.gradient)
                    .frame(width: SliderData.protsWidth)
                    .overlay(alignment: .topLeading)
                    {
                        Text("\(String(format: "%.0f", SliderData.protsWidth / maxSlider * 100))\(SliderData.protsWidth / maxSlider <= 0.11 ? "" : "%")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9))
                            .offset(x: 6, y: 4)
                    }
                    .offset(x: SliderData.carbsWidth + SliderData.fatsWidth)
                
                // leading handle
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: 40)
                    .contentShape(.rect)
                    .offset(x: SliderData.carbsWidth - 20)
                    .gesture(getLeadingGesture(maxSlider: maxSlider))

                // trailing handle
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: 40)
                
                .contentShape(.rect)
                .offset(x: (SliderData.carbsWidth + SliderData.fatsWidth) - 20)
                .gesture(getTrailingGesture(maxSlider: maxSlider))
            }
            .task
            {
                // use appsotrage ratio for control width init
                SliderData.ratioToWidth(maxSlider)
                
                Task { await SliderData.updateMacroWeights() }
            }
            .onChange(of: AppSettings.weightGoal)
            {
                Task { await SliderData.updateMacroWeights() }
            }
            .onChange(of: AppSettings.dataSource)
            {
                Task { await SliderData.updateMacroWeights() }
            }
            .onChange(of: AppSettings.energyUnit)
            {
                Task { await SliderData.updateMacroWeights() }
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    func getTrailingGesture(maxSlider: Double) -> _EndedGesture<_ChangedGesture<DragGesture>>
    {
        return DragGesture(minimumDistance: 0)
            .onChanged
            { value in
                let minSegment = maxSlider * SliderData.minSegmentRatio
                let maxSegment = maxSlider * SliderData.maxSegmentRatio
                
                // Add dragged width to last prots bar width and clamp to constraints
                let snapWidth = maxSlider * SliderData.snapTo  // Calculate width for 5% snap
                var widthNew = SliderData.protsWidthLast + -value.translation.width
                
                // Snap to nearest 5%
                widthNew = (widthNew / snapWidth).rounded() * snapWidth
                widthNew = max(minSegment, min(widthNew, maxSegment))
                
                let widthAdded = widthNew - SliderData.protsWidth

                // If fats width would stay within constraints ...
                if SliderData.fatsWidth - widthAdded >= minSegment
                {
                    // ... take dragged width from fats bar
                    SliderData.fatsWidth -= widthAdded
                }
                // If fats bar is too small to donate in full ...
                else
                {
                    // ... take as much from fats as possible, setting it to the minimum
                    let availableFromFats = SliderData.fatsWidth - minSegment
                    SliderData.fatsWidth = minSegment

                    let neededFromCarbs = widthAdded - availableFromFats

                    // If carbs width would stay within constraints ...
                    if SliderData.carbsWidth - neededFromCarbs >= minSegment
                    {
                        // ... take rest from carbs bar
                        SliderData.carbsWidth -= neededFromCarbs
                    }
                    // If prots bar has been expanded maximally ...
                    else
                    {
                        // ... collapse carbs maximally
                        SliderData.carbsWidth = minSegment

                        widthNew = maxSegment
                    }
                }

                SliderData.protsWidth = widthNew
                
                SliderData.widthToRatio(maxSlider)
                Task { await SliderData.updateMacroWeights() }
                
            }
            .onEnded
            { _ in
                SliderData.carbsWidthLast = SliderData.carbsWidth
                SliderData.fatsWidthLast = SliderData.fatsWidth
                SliderData.protsWidthLast = SliderData.protsWidth

                SliderData.widthToRatio(maxSlider)
                Task { await SliderData.updateMacroWeights() }
            }
    }
    
    func getLeadingGesture(maxSlider: Double) -> _EndedGesture<_ChangedGesture<DragGesture>>
    {
        let minSegment = maxSlider * SliderData.minSegmentRatio
        let maxSegment = maxSlider * SliderData.maxSegmentRatio
        
        let r = DragGesture(minimumDistance: 0)
            .onChanged
            { value in
                // Add dragged width to latest carb segment width and clamp to constraints
                let snapWidth = maxSlider * SliderData.snapTo  // Calculate width for 5% snap
                var widthNew = SliderData.carbsWidthLast + value.translation.width
                
                // Snap to nearest 5%
                widthNew = (widthNew / snapWidth).rounded() * snapWidth
                widthNew = max(minSegment, min(widthNew, maxSegment))

                let widthAdded = widthNew - SliderData.carbsWidth
                
                // If fats width would stay within constraints ...
                if SliderData.fatsWidth - widthAdded >= minSegment
                {
                    // ... take dragged width from fats bar
                    SliderData.fatsWidth -= widthAdded
                }
                // If fats bar is too small to donate in full ...
                else
                {
                    // ... take as much from fats as possible, setting it to the minimum
                    let availableFromFats = SliderData.fatsWidth - minSegment
                    SliderData.fatsWidth = minSegment
                    
                    let neededFromProts = widthAdded - availableFromFats
                    
                    // If prots width would stay within constraints ...
                    if SliderData.protsWidth - neededFromProts >= minSegment
                    {
                        // ... take rest from prots bar
                        SliderData.protsWidth -= neededFromProts
                    }
                    // If carbs bar has been expanded maximally ...
                    else
                    {
                        // ... collapse prots maximally
                        SliderData.protsWidth = minSegment
                        
                        widthNew = maxSegment
                    }
                }

                SliderData.carbsWidth = widthNew
                SliderData.widthToRatio(maxSlider)
                
                Task { await SliderData.updateMacroWeights() }
            }
            .onEnded
            { value in
                SliderData.carbsWidthLast = SliderData.carbsWidth
                SliderData.fatsWidthLast = SliderData.fatsWidth
                SliderData.protsWidthLast = SliderData.protsWidth
                
                // translate raw ui-element data to macro ratios
                SliderData.widthToRatio(maxSlider)
                Task { await SliderData.updateMacroWeights() }
            }
        
        return r
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
