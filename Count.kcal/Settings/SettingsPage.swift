import SwiftUI
import WidgetKit

/// Settings screen for goals, units, and appearance.
struct SettingsPage: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.colorScheme) private var scheme: ColorScheme
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            AppSettings.AppBackground.ignoresSafeArea(.all)
            
            ScrollView {
                EnergySettingsView(focusedField: _focusedField)
                    .padding(.bottom, 20)

                VStack(spacing: 30) {
                    NutrientsCard()
                    StepsCard(focusedField: _focusedField)
                    UnitsCard()
                    DashboardCustomizationCard()
                    OtherSettingsCard()
                    ColorsCard()
                }
                .accessibilityScrollWidth(dynamicType.isAccessibilitySize)
                
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        if !dynamicType.isAccessibilitySize {
                            Image(systemName: "laurel.leading")
                                .font(.system(size: 42))
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(
                                    colors: [Color("TextColor"), Color("TextColor").opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        }

                        Link(
                            destination: URL(
                                string: "https://apps.apple.com/us/app/count-kcal/id6476797015?action=write-review"
                            )!
                        ) {
                            VStack(spacing: 4) {
                                (dynamicType.isAccessibilitySize
                                    ? AnyLayout(VStackLayout(alignment: .center, spacing: 4))
                                    : AnyLayout(HStackLayout(spacing: 4))) {
                                    Text("Rate us on the")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color("TextColor").opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(verbatim: "App Store")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color("TextColor"))
                                        .underline()
                                        .shadow(color: Color("TextColor").opacity(0.4), radius: 10, y: -2)
                                }

                                HStack() {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: "star.fill")
                                            .font(.subheadline)
                                            .fontWeight(.black)
                                            .foregroundStyle(.yellow.opacity(0.9).gradient)
                                    }
                                    
                                    Text(verbatim: "5 / 5")
                                        .font(.caption)
                                        .fontWeight(.light)
                                        .opacity(0.7)
                                        .offset(x: -2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if !dynamicType.isAccessibilitySize {
                            Image(systemName: "laurel.trailing")
                                .font(.system(size: 42))
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(
                                    colors: [Color("TextColor"), Color("TextColor").opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        }
                    }
                    .padding(.top, 10)
                    .foregroundStyle(Color("TextColor"))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    
                    Divider()
                        .frame(width: 190)
                        .padding(.vertical, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                
                    (dynamicType.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .center, spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 24))) {
                        Link(destination: URL(string: "https://x.com/BerkenSayilir")!) {
                            HStack(spacing: 3) {
                                Text("Contact")
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryTextColor"))
                                    .fontWeight(.medium)
                                    .padding(.trailing, 4)
                                
                                Image(systemName: "bubble")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(Color("TextColor"))
                                    .frame(height: 14)
                                    .fontWeight(.medium)
                                    .offset(y: 1)
                                
                                Image(scheme == .dark ? "XAppWhite" : "XAppBlack")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 18)
                                    .opacity(0.9)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Link(destination: URL(string: "https://count.mottzi.de/help")!) {
                            HStack(spacing: 3) {
                                Text("Support")
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryTextColor"))
                                    .fontWeight(.medium)
                                
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(Color("TextColor"))
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .padding(.bottom)
                }
                .padding(.top, 6)
                .accessibilityScrollWidth(dynamicType.isAccessibilitySize)

                #if DEBUG
                DebugSettingsCard()
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .accessibilityScrollWidth(dynamicType.isAccessibilitySize)
                #endif
            }
            .scrollIndicators(.hidden)
            .softTopScrollEdge()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(usesLegacyToolbar)
            .onDisappear {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundStyle(Color("TextColor"))
                }

                if usesLegacyToolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.callout)
                                Text("Back")
                            }
                            .foregroundColor(Color("TextColor"))
                            .fontWeight(.semibold)
                        }
                        .padding(.leading, 16)
                    }
                }
                
            }
        }
    }

}

extension SettingsPage {

    private var usesLegacyToolbar: Bool {
        if #available(iOS 26, *) { false } else { true }
    }

}

private extension View {

    @ViewBuilder
    func accessibilityScrollWidth(_ enabled: Bool) -> some View {
        if enabled {
            containerRelativeFrame(.horizontal)
        } else {
            self
        }
    }

}

enum Field: Int, CaseIterable {

    case balance, carbs, fats, protein, passive, active, steps

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
