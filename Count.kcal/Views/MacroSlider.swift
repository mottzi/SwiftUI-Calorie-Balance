import SwiftUI

@MainActor
@Observable
/// Macro slider widths and saved goal ratios.
final class HSlider {

    private(set) var carbsWidth: CGFloat = 0
    private(set) var fatsWidth: CGFloat = 0
    private(set) var protsWidth: CGFloat = 0

    private(set) var selectionFeedbackTrigger = 0

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var sliderWidth: CGFloat = 0

    @ObservationIgnored private var carbsWidthLast: CGFloat = 0
    @ObservationIgnored private var protsWidthLast: CGFloat = 0
    
    private let minSegmentRatio: CGFloat = 0.1
    private let snapTo: CGFloat = 0.05

    init(settings: Settings? = nil) { self.settings = settings ?? .shared }

}

extension HSlider {

    /// Resizes only when the measured width changes by at least a screen pixel.
    func resize(to width: CGFloat, displayScale: CGFloat) {
        guard width > 0, displayScale > 0 else { return }
        // Layout noise must not overwrite the saved origin of an active drag.
        guard abs(width - sliderWidth) * displayScale >= 1 else { return }
        ratioToWidth(width)
    }

    func ratioToWidth(_ maxSlider: CGFloat) {
        guard maxSlider > 0 else { return }
        sliderWidth = maxSlider
        carbsWidth = maxSlider * settings.carbsRatio
        carbsWidthLast = carbsWidth
        
        fatsWidth = maxSlider * settings.fatsRatio
        
        protsWidth = maxSlider * settings.proteinRatio
        protsWidthLast = protsWidth
    }

}

extension HSlider {

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
        // Ignore callbacks within the same snap, including floating-point layout noise.
        guard abs(newOuterWidth - outerWidth) / maxWidth > 0.000000001 else { return }
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
        selectionFeedbackTrigger += 1
    }

    /// Saves the segment widths after a handle drag ends.
    fileprivate func finishDrag(maxWidth: CGFloat) {

        guard maxWidth > 0 else { return }
        carbsWidthLast = carbsWidth
        protsWidthLast = protsWidth
        widthToRatio(maxWidth)
    }

}

extension HSlider {

    private var maxSegmentRatio: CGFloat { 1 - minSegmentRatio - minSegmentRatio }

    private func widthToRatio(_ maxSlider: CGFloat) {
        guard maxSlider > 0 else { return }
        let carbsRatio = carbsWidth / maxSlider
        let fatsRatio = fatsWidth / maxSlider
        let proteinRatio = protsWidth / maxSlider
        if abs(settings.carbsRatio - carbsRatio) > 0.000000001 { settings.carbsRatio = carbsRatio }
        if abs(settings.fatsRatio - fatsRatio) > 0.000000001 { settings.fatsRatio = fatsRatio }
        if abs(settings.proteinRatio - proteinRatio) > 0.000000001 { settings.proteinRatio = proteinRatio }
    }

}

/// Slider for adjusting carbohydrate, fat, and protein goal shares.
struct MacroSlider: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.displayScale) private var displayScale

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
                        if !dynamicType.isAccessibilitySize {
                            Text(segmentLabel(SliderData.carbsWidth, total: maxSlider))
                                .font(.caption)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
                                .offset(x: 6, y: 4)
                        }
                    }
                
                // Fats slider segment
                Rectangle()
                    .fill(Color(red: 217/255, green: 220/255, blue: 214/255).gradient)
                    .frame(width: SliderData.fatsWidth)
                    .overlay(alignment: .topLeading) {
                        if !dynamicType.isAccessibilitySize {
                            Text(segmentLabel(SliderData.fatsWidth, total: maxSlider))
                                .font(.caption)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
                                .offset(x: 6, y: 4)
                        }
                    }
                    .offset(x: SliderData.carbsWidth)
                
                // Prots slider segment
                Rectangle()
                    .fill(.red.gradient)
                    .frame(width: SliderData.protsWidth)
                    .overlay(alignment: .topLeading) {
                        if !dynamicType.isAccessibilitySize {
                            Text(segmentLabel(SliderData.protsWidth, total: maxSlider))
                                .font(.caption)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("ContrastColor").brighten(-0.9, in: colorEnvironment))
                                .offset(x: 6, y: 4)
                        }
                    }
                    .offset(x: SliderData.carbsWidth + SliderData.fatsWidth)
                
                // leading handle
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: dynamicType.isAccessibilitySize ? 48 : 40)
                    .contentShape(.rect)
                    .offset(x: SliderData.carbsWidth - (dynamicType.isAccessibilitySize ? 24 : 20))
                    .gesture(dragGesture(for: .leading, maxWidth: maxSlider))

                // trailing handle
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: dynamicType.isAccessibilitySize ? 48 : 40)
                
                .contentShape(.rect)
                .offset(x: (SliderData.carbsWidth + SliderData.fatsWidth) - (dynamicType.isAccessibilitySize ? 24 : 20))
                .gesture(dragGesture(for: .trailing, maxWidth: maxSlider))
            }
            .sensoryFeedback(.selection, trigger: SliderData.selectionFeedbackTrigger)
            .task {
                SliderData.ratioToWidth(maxSlider)
            }
            .onChange(of: maxSlider) { _, width in
                SliderData.resize(to: width, displayScale: displayScale)
            }
        }
        .frame(height: dynamicType.isAccessibilitySize ? 50 : 40)
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
