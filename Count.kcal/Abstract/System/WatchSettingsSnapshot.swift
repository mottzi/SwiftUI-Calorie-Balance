import SwiftUI

/// Settings values exchanged with the Watch through a property-list context.
struct WatchSettingsSnapshot: Codable, Equatable, Sendable {

    let weightGoal: Int?
    let dataSource: Int?
    let energyUnit: String?
    let weightUnit: String?
    let balanceGoal: Int?
    let customCalPassive: Int?
    let customCalActive: Int?
    var stepsGoal: Int? = nil
    let proteinGoal: Int?
    let carbsGoal: Int?
    let fatsGoal: Int?
    let burnedColor: String?
    let consumedColor: String?
    var usesSampleData: Bool? = nil
    var usesMarketingData: Bool? = nil
    var weightHistory: WeightHistorySnapshot? = nil

}

extension WatchSettingsSnapshot {

    init?(context: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: context,
            format: .binary,
            options: 0
        ) else { return nil }
        guard let snapshot = try? PropertyListDecoder().decode(Self.self, from: data) else { return nil }
        self = snapshot
    }

    @MainActor
    init(settings: Settings, weightHistory: WeightHistorySnapshot?) {

        self.init(
            weightGoal: settings.weightGoal.rawValue,
            dataSource: settings.dataSource.rawValue,
            energyUnit: settings.energyUnit.rawValue,
            weightUnit: settings.weightUnit.rawValue,
            balanceGoal: settings.balanceGoal,
            customCalPassive: settings.customCalPassive,
            customCalActive: settings.customCalActive,
            stepsGoal: settings.stepsGoal,
            proteinGoal: settings.proteinGoal,
            carbsGoal: settings.carbsGoal,
            fatsGoal: settings.fatsGoal,
            burnedColor: settings.burnedColor.rawValue,
            consumedColor: settings.consumedColor.rawValue,
            usesSampleData: Self.sampleModeForTransfer,
            usesMarketingData: Self.marketingModeForTransfer,
            weightHistory: weightHistory?.unit == settings.weightUnit.rawValue ? weightHistory : nil
        )
    }

}

extension WatchSettingsSnapshot {

    var context: [String: Any]? {
        guard let data = try? PropertyListEncoder().encode(self) else { return nil }
        guard let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        return propertyList as? [String: Any]
    }

}

extension WatchSettingsSnapshot {

    @MainActor
    func apply(to settings: Settings) {
        #if DEBUG && os(watchOS)
        if let usesSampleData { HealthDataMode.shared.usesSampleData = usesSampleData }
        if let usesMarketingData { HealthDataMode.shared.usesMarketingData = usesMarketingData }
        #endif

        if let weightGoal, let value = Settings.WeightGoals(rawValue: weightGoal) {
            settings.weightGoal = value
        }
        if let dataSource, let value = Settings.DataSources(rawValue: dataSource) {
            settings.dataSource = value
        }
        if let energyUnit, let value = Settings.EnergyUnit(rawValue: energyUnit) {
            settings.energyUnit = value
        }
        if let weightUnit, let value = Settings.WeightUnit(rawValue: weightUnit) {
            settings.weightUnit = value
        }
        if let balanceGoal { settings.balanceGoal = balanceGoal }
        if let customCalPassive { settings.customCalPassive = customCalPassive }
        if let customCalActive { settings.customCalActive = customCalActive }
        if let stepsGoal { settings.stepsGoal = stepsGoal }
        if let proteinGoal { settings.proteinGoal = proteinGoal }
        if let carbsGoal { settings.carbsGoal = carbsGoal }
        if let fatsGoal { settings.fatsGoal = fatsGoal }
        if let burnedColor, let color = Color(rawValue: burnedColor) {
            settings.burnedColor = color
        }
        if let consumedColor, let color = Color(rawValue: consumedColor) {
            settings.consumedColor = color
        }
    }

}

extension WatchSettingsSnapshot {

    @MainActor
    private static var sampleModeForTransfer: Bool? {
        #if DEBUG
        HealthDataMode.isSampleDataEnabled
        #else
        nil
        #endif
    }

    @MainActor
    private static var marketingModeForTransfer: Bool? {
        #if DEBUG
        HealthDataMode.isMarketingDataEnabled
        #else
        nil
        #endif
    }

}
