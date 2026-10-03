#if DEBUG
import SwiftUI

/// Keeps development controls together at the bottom of Settings.
struct DebugSettingsCard: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.dismiss) private var dismiss

    @State private var healthDataMode = HealthDataMode.shared

    #if targetEnvironment(simulator)
    @State private var isSeedingHealthData = false
    @State private var showSeedResult = false
    @State private var seedResultMessage = ""
    #endif

    var body: some View {
        @Bindable var mode = healthDataMode

        Card("Debug", titlePadding: false) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use Sample Health Data", isOn: $mode.usesSampleData)
                    .tint(.green)
                    .fontWeight(.semibold)

                #if targetEnvironment(simulator)
                Button("Seed Simulator Health Data", systemImage: "cross.case", action: seedHealthData)
                    .disabled(isSeedingHealthData || healthDataMode.usesSampleData)
                    .fontWeight(.semibold)
                #endif

                Divider()
                    .padding(.vertical, 4)

                Button("Restart Onboarding", systemImage: "arrow.counterclockwise", action: restartOnboarding)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .font(.subheadline)
            .foregroundStyle(Color("TextColor"))
            .tint(Color("TextColor"))
        }
        #if targetEnvironment(simulator)
        .disabled(isSeedingHealthData)
        .alert("Simulator Health Data", isPresented: $showSeedResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(seedResultMessage)
        }
        #endif
    }

}

extension DebugSettingsCard {

    private func restartOnboarding() {
        AppSettings.showWelcome = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
    }

    #if targetEnvironment(simulator)
    private func seedHealthData() {
        isSeedingHealthData = true
        Task {
            do {
                let count = try await SimulatorHealthSeeder.seed()
                seedResultMessage = "Saved \(count) simulator Health samples."
            } catch {
                seedResultMessage = "Could not seed Health data: \(error)"
            }
            isSeedingHealthData = false
            showSeedResult = true
        }
    }
    #endif

}
#endif
