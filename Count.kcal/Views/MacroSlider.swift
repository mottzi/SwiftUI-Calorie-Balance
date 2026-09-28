import SwiftUI

@MainActor
@Observable
/// Macro slider widths and saved goal ratios.
final class HSlider {

    @ObservationIgnored private let settings: Settings

    var carbsWidthLast: CGFloat = 0
    var fatsWidthLast: CGFloat = 0
    var protsWidthLast: CGFloat = 0
    
    var carbsWidth: CGFloat = 0
    var fatsWidth: CGFloat = 0
    var protsWidth: CGFloat = 0
    
    var minSegmentRatio: CGFloat = 0.1
    var snapTo = 0.05

    init(settings: Settings = .shared) { self.settings = settings }

    /// Updates macro weight goals from the current energy budget and ratios.
    func updateMacroWeights() {
        let maxEnergy = settings.maxEatingEnergy()
        settings.carbsGoal = ratioToWeight(
            maxEatingEnergy: maxEnergy,
            ratio: settings.carbsRatio,
            type: .carbohydrates
        )
        settings.fatsGoal = ratioToWeight(maxEatingEnergy: maxEnergy, ratio: settings.fatsRatio, type: .fats)
        settings.proteinGoal = ratioToWeight(
            maxEatingEnergy: maxEnergy,
            ratio: settings.proteinRatio,
            type: .proteins
        )
    }

}

extension HSlider {

    var maxSegmentRatio: CGFloat { 1 - minSegmentRatio - minSegmentRatio }

    func ratioToWidth(_ maxSlider: CGFloat) {
        guard maxSlider > 0 else { return }
        let minSegment = maxSlider * minSegmentRatio

        if settings.carbsRatio * maxSlider < minSegment
            || settings.fatsRatio * maxSlider < minSegment
            || settings.proteinRatio * maxSlider < minSegment {
            settings.carbsRatio = 0.4
            settings.fatsRatio = 0.35
            settings.proteinRatio = 0.25
        }
        
        carbsWidth = maxSlider * settings.carbsRatio
        carbsWidthLast = carbsWidth
        
        fatsWidth = maxSlider * settings.fatsRatio
        fatsWidthLast = fatsWidth
        
        protsWidth = maxSlider * settings.proteinRatio
        protsWidthLast = protsWidth
    }
    
    func widthToRatio(_ maxSlider: CGFloat) {
        guard maxSlider > 0 else { return }
        settings.carbsRatio = carbsWidth / maxSlider
        settings.fatsRatio = fatsWidth / maxSlider
        settings.proteinRatio = protsWidth / maxSlider
    }
    
    func ratioToWeight(maxEatingEnergy: Int, ratio: Double, type: MacroType) -> Int {
        var energyDensity: Double
        
        switch type {
            case .carbohydrates: energyDensity = 4
            case .fats: energyDensity = 9
            case .proteins: energyDensity = 4
        }
        
        energyDensity = settings.energyUnit == .kcal ? energyDensity : energyDensity * 4.184
        
        return Int((Double(maxEatingEnergy) * ratio / Double(energyDensity)).rounded())
    }

}

/// Slider for adjusting carbohydrate, fat, and protein goal shares.
struct MacroSlider: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(HSlider.self) private var SliderData
    
    var body: some View {
        GeometryReader { geo in
            let maxSlider = geo.size.width
            
            ZStack(alignment: .leading) {
                // Carbs slider segment
                Rectangle()
                    .fill(.orange.gradient)
                    .frame(width: SliderData.carbsWidth)
                    .overlay(alignment: .topLeading) {
                        Text(segmentLabel(SliderData.carbsWidth, total: maxSlider))
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
                            .offset(x: 6, y: 4)
                    }
                
                // Fats slider segment
                Rectangle()
                    .fill(Color(red: 217/255, green: 220/255, blue: 214/255).gradient)
                    .frame(width: SliderData.fatsWidth)
                    .overlay(alignment: .topLeading) {
                        Text(segmentLabel(SliderData.fatsWidth, total: maxSlider))
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
                            .offset(x: 6, y: 4)
                    }
                    .offset(x: SliderData.carbsWidth)
                    .sensoryFeedback(trigger: SliderData.fatsWidth) { o, n in o != 0 ? .selection : nil }
                
                // Prots slider segment
                Rectangle()
                    .fill(.red.gradient)
                    .frame(width: SliderData.protsWidth)
                    .overlay(alignment: .topLeading) {
                        Text(segmentLabel(SliderData.protsWidth, total: maxSlider))
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
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
            .task {
                SliderData.ratioToWidth(maxSlider)
                SliderData.updateMacroWeights()
            }
            .onChange(of: maxSlider) { _, width in
                SliderData.ratioToWidth(width)
            }
            .onChange(of: macroGoalInput) {
                SliderData.updateMacroWeights()
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
}

extension MacroSlider {

    private var colorEnvironment: EnvironmentValues {
        var values = EnvironmentValues()
        values.colorScheme = colorScheme
        return values
    }

    private var macroGoalInput: MacroGoalInput {
        MacroGoalInput(energy: AppSettings.maxEatingEnergy(), unit: AppSettings.energyUnit)
    }

    private func segmentLabel(_ width: CGFloat, total: CGFloat) -> String {
        guard total > 0 else { return "0" }
        let ratio = width / total
        return "\(String(format: "%.0f", ratio * 100))\(ratio <= 0.11 ? "" : "%")"
    }

    func getTrailingGesture(maxSlider: Double) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard maxSlider > 0 else { return }
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
                if SliderData.fatsWidth - widthAdded >= minSegment {
                    // ... take dragged width from fats bar
                    SliderData.fatsWidth -= widthAdded
                }
                // If fats bar is too small to donate in full ...
                else {
                    // ... take as much from fats as possible, setting it to the minimum
                    let availableFromFats = SliderData.fatsWidth - minSegment
                    SliderData.fatsWidth = minSegment

                    let neededFromCarbs = widthAdded - availableFromFats

                    // If carbs width would stay within constraints ...
                    if SliderData.carbsWidth - neededFromCarbs >= minSegment {
                        // ... take rest from carbs bar
                        SliderData.carbsWidth -= neededFromCarbs
                    }
                    // If prots bar has been expanded maximally ...
                    else {
                        // ... collapse carbs maximally
                        SliderData.carbsWidth = minSegment

                        widthNew = maxSegment
                    }
                }

                SliderData.protsWidth = widthNew
                
                SliderData.widthToRatio(maxSlider)
                SliderData.updateMacroWeights()
                
            }
            .onEnded { _ in
                guard maxSlider > 0 else { return }
                SliderData.carbsWidthLast = SliderData.carbsWidth
                SliderData.fatsWidthLast = SliderData.fatsWidth
                SliderData.protsWidthLast = SliderData.protsWidth

                SliderData.widthToRatio(maxSlider)
                SliderData.updateMacroWeights()
            }
    }
    
    func getLeadingGesture(maxSlider: Double) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        let minSegment = maxSlider * SliderData.minSegmentRatio
        let maxSegment = maxSlider * SliderData.maxSegmentRatio
        
        let r = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard maxSlider > 0 else { return }
                // Add dragged width to latest carb segment width and clamp to constraints
                let snapWidth = maxSlider * SliderData.snapTo  // Calculate width for 5% snap
                var widthNew = SliderData.carbsWidthLast + value.translation.width
                
                // Snap to nearest 5%
                widthNew = (widthNew / snapWidth).rounded() * snapWidth
                widthNew = max(minSegment, min(widthNew, maxSegment))

                let widthAdded = widthNew - SliderData.carbsWidth
                
                // If fats width would stay within constraints ...
                if SliderData.fatsWidth - widthAdded >= minSegment {
                    // ... take dragged width from fats bar
                    SliderData.fatsWidth -= widthAdded
                }
                // If fats bar is too small to donate in full ...
                else {
                    // ... take as much from fats as possible, setting it to the minimum
                    let availableFromFats = SliderData.fatsWidth - minSegment
                    SliderData.fatsWidth = minSegment
                    
                    let neededFromProts = widthAdded - availableFromFats
                    
                    // If prots width would stay within constraints ...
                    if SliderData.protsWidth - neededFromProts >= minSegment {
                        // ... take rest from prots bar
                        SliderData.protsWidth -= neededFromProts
                    }
                    // If carbs bar has been expanded maximally ...
                    else {
                        // ... collapse prots maximally
                        SliderData.protsWidth = minSegment
                        
                        widthNew = maxSegment
                    }
                }

                SliderData.carbsWidth = widthNew
                SliderData.widthToRatio(maxSlider)
                
                SliderData.updateMacroWeights()
            }
            .onEnded { value in
                guard maxSlider > 0 else { return }
                SliderData.carbsWidthLast = SliderData.carbsWidth
                SliderData.fatsWidthLast = SliderData.fatsWidth
                SliderData.protsWidthLast = SliderData.protsWidth
                
                // translate raw ui-element data to macro ratios
                SliderData.widthToRatio(maxSlider)
                SliderData.updateMacroWeights()
            }
        
        return r
    }

}

/// Energy inputs that change macro weight goals without changing the slider ratios.
private struct MacroGoalInput: Equatable {

    let energy: Int
    let unit: Settings.EnergyUnit

}

enum MacroType {

    case carbohydrates
    case fats
    case proteins

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
