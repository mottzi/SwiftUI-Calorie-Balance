#if DEBUG
import SwiftUI

/// Keeps development controls together at the bottom of Settings.
struct DebugSettingsCard: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.dismiss) private var dismiss

    @State private var healthDataMode = HealthDataMode.shared
    @State private var sharing = SharingRuntime.shared

    #if targetEnvironment(simulator)
    @State private var isSeedingHealthData = false
    @State private var showSeedResult = false
    @State private var seedResultMessage = ""
    #endif

    var body: some View {
        @Bindable var mode = healthDataMode
        @Bindable var sharing = sharing

        Card("Debug") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use Sample Health Data", isOn: $mode.usesSampleData)
                    .tint(.green)
                    .fontWeight(.semibold)

                if mode.usesSampleData {
                    HStack {
                        Text("Sample profile")
                            .fontWeight(.semibold)
                        Spacer()
                        Menu {
                            Picker("Sample profile", selection: $mode.sampleProfile) {
                                ForEach(SampleHealthProfile.allCases) { profile in
                                    Text(profile.title).tag(profile)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(mode.sampleProfile.title)
                                    .font(.system(.body, design: .rounded))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sample profile")
                        .accessibilityValue(Text(mode.sampleProfile.title))
                        .disabled(mode.usesMarketingData)
                    }

                    Text(mode.usesMarketingData
                         ? "Turn off Marketing Mode to use sample profiles."
                         : mode.sampleProfile.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Marketing Mode", isOn: $mode.usesMarketingData)
                        .tint(.green)
                        .fontWeight(.semibold)
                }

                #if targetEnvironment(simulator)
                Button("Seed Simulator Health Data", systemImage: "cross.case", action: seedHealthData)
                    .disabled(isSeedingHealthData || healthDataMode.usesSampleData)
                    .fontWeight(.semibold)
                #endif

                Divider()
                    .padding(.vertical, 4)

                Toggle("Show Four Sample People", isOn: $sharing.samplePeopleEnabled)
                    .tint(.green)
                    .fontWeight(.semibold)

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
        dismiss()
        AppSettings.showWelcome = true
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
