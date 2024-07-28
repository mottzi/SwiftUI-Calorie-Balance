import SwiftUI

enum GraphMode 
{
    case now
    case midnight
}

struct CircleBalanceGraph: View
{
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel

    let trimRatio = 0.25
    var lineWidth: CGFloat = 8
    
    let mode: GraphMode
    
    var passiveFuture: Int { mode == .midnight ? max(DataViewModel.sample.burnedPassive7 - DataViewModel.sample.burnedPassive, 0) : 0 }
    
    var maxNow: Int { max(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive, DataViewModel.sample.consumed) }
    var maxMidnight: Int { max((AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7) + DataViewModel.sample.burnedPassive + passiveFuture, DataViewModel.sample.consumed) }
    
    var activeNow: Double { maxNow == 0 ? 0.0 : Double(DataViewModel.sample.burnedActive) / Double(maxNow) }
    var passiveNow: Double { maxNow == 0 ? 0.0 : Double(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive) / Double(maxNow) }
    var consumedNow: Double { maxNow == 0 ? 0.0 : Double(DataViewModel.sample.consumed) / Double(maxNow) }
    
    var activeMidnight: Double { maxMidnight == 0 ? 0.0 : (AppSettings.dataSource == .apple ? Double(DataViewModel.sample.burnedActive) : Double(DataViewModel.sample.burnedActive7)) / Double(maxMidnight) }
    var passiveMidnight: Double { maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7) + DataViewModel.sample.burnedPassive) / Double(maxMidnight) }
    var passiveFutureMidnight: Double { maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7) + DataViewModel.sample.burnedPassive + passiveFuture) / Double(maxMidnight) }
    var consumedMidnight: Double { maxMidnight == 0 ? 0.0 : Double(DataViewModel.sample.consumed) / Double(maxMidnight) }

    var body: some View
    {
        if mode == .midnight
        {
            GeometryReader
            { geo in
                ZStack
                {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)

                    // passive future
                    CircleProgressView(progress: passiveFutureMidnight, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .tertiary, to: .circlegraphMidnight)
                    
                    // passive
                    CircleProgressView(progress: passiveMidnight, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .secondary, to: .circlegraphMidnight)
                        
                    // active
                    CircleProgressView(progress: activeMidnight, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .primary, to: .circlegraphMidnight)

                        // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25), height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25))
                        .brightness(level: .primary)
                        
                        // consumed
                    CircleProgressView(progress: consumedMidnight, color: AppSettings.consumedColor, lineWidth: lineWidth)
                        .frame(width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25), height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25))
                        .brightness(level: .primary)
                }
                .saturation(Settings.baseSaturation)
                .brightness(scheme == .dark ? -0.1 : 0.0)
            }
            .padding(lineWidth / 2)
        }
        else
        {
            GeometryReader
            { geo in
                ZStack
                {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)

                    // passive
                    CircleProgressView(progress: passiveNow, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .secondary, to: .circlegraphNow)
                        
                    // active
                    CircleProgressView(progress: activeNow, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .primary, to: .circlegraphNow)

                        // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25), height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25))
                        .brightness(level: .primary)
                        
                        // consumed
                    CircleProgressView(progress: consumedNow, color: AppSettings.consumedColor, lineWidth: lineWidth)
                        .frame(width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25), height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25))
                        .brightness(level: .primary)
                }
                .saturation(Settings.baseSaturation)
                .brightness(scheme == .dark ? -0.1 : 0.0)
            }
            .padding(lineWidth / 2)
        }
    }
}
