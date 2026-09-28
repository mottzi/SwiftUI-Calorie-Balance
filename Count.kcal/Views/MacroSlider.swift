import SwiftUI

@MainActor
@Observable
/// Macro slider widths and saved goal ratios.
final class HSlider {

    @ObservationIgnored private let settings: Settings

    private var carbsWidthLast: CGFloat = 0
    private var fatsWidthLast: CGFloat = 0
    private var protsWidthLast: CGFloat = 0
    
    private(set) var carbsWidth: CGFloat = 0
    private(set) var fatsWidth: CGFloat = 0
    private(set) var protsWidth: CGFloat = 0
    
    private let minSegmentRatio: CGFloat = 0.1
    private let snapTo: CGFloat = 0.05

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

    private var maxSegmentRatio: CGFloat { 1 - minSegmentRatio - minSegmentRatio }

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
    
    private func widthToRatio(_ maxSlider: CGFloat) {
        guard maxSlider > 0 else { return }
        settings.carbsRatio = carbsWidth / maxSlider
        settings.fatsRatio = fatsWidth / maxSlider
        settings.proteinRatio = protsWidth / maxSlider
    }

    /// Moves one slider handle while preserving the minimum width of each segment.
    fileprivate func moveBoundary(_ handle: SliderHandle, translation: CGFloat, maxWidth: CGFloat) {

        guard maxWidth > 0 else { return }
        let minWidth = maxWidth * minSegmentRatio
        let maxOuterWidth = maxWidth * maxSegmentRatio
        let snapWidth = maxWidth * snapTo
        let isLeading = handle == .leading
        let outerWidth = isLeading ? carbsWidth : protsWidth
        let outerWidthLast = isLeading ? carbsWidthLast : protsWidthLast
        var oppositeWidth = isLeading ? protsWidth : carbsWidth
        var middleWidth = fatsWidth

        // snap the dragged outer segment before taking width from its neighbors
        var newOuterWidth = outerWidthLast + translation * (isLeading ? 1 : -1)
        newOuterWidth = (newOuterWidth / snapWidth).rounded() * snapWidth
        newOuterWidth = max(minWidth, min(newOuterWidth, maxOuterWidth))
        let widthAdded = newOuterWidth - outerWidth

        if middleWidth - widthAdded >= minWidth {
            middleWidth -= widthAdded
        } else {
            // use the opposite segment only after the middle segment reaches its minimum
            let availableFromMiddle = middleWidth - minWidth
            middleWidth = minWidth
            let neededFromOpposite = widthAdded - availableFromMiddle
            if oppositeWidth - neededFromOpposite >= minWidth {
                oppositeWidth -= neededFromOpposite
            } else {
                oppositeWidth = minWidth
                newOuterWidth = maxOuterWidth
            }
        }

        fatsWidth = middleWidth
        if isLeading {
            carbsWidth = newOuterWidth
            protsWidth = oppositeWidth
        } else {
            protsWidth = newOuterWidth
            carbsWidth = oppositeWidth
        }
        widthToRatio(maxWidth)
        updateMacroWeights()
    }

    /// Saves the segment widths after a handle drag ends.
    fileprivate func finishDrag(maxWidth: CGFloat) {

        guard maxWidth > 0 else { return }
        carbsWidthLast = carbsWidth
        fatsWidthLast = fatsWidth
        protsWidthLast = protsWidth
        widthToRatio(maxWidth)
        updateMacroWeights()
    }
    
    private func ratioToWeight(maxEatingEnergy: Int, ratio: Double, type: MacroType) -> Int {
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
                    .gesture(dragGesture(for: .leading, maxWidth: maxSlider))

                // trailing handle
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: 40)
                
                .contentShape(.rect)
                .offset(x: (SliderData.carbsWidth + SliderData.fatsWidth) - 20)
                .gesture(dragGesture(for: .trailing, maxWidth: maxSlider))
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

    private func dragGesture(for handle: SliderHandle, maxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                SliderData.moveBoundary(handle, translation: value.translation.width, maxWidth: maxWidth)
            }
            .onEnded { _ in
                SliderData.finishDrag(maxWidth: maxWidth)
            }
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

/// Handle that moves one outer macro segment against the middle segment.
fileprivate enum SliderHandle {

    case leading
    case trailing

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
