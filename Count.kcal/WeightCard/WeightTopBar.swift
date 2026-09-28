import SwiftUI

struct WeightTopBar: View {

    @Environment(\.colorScheme) private var scheme: ColorScheme
    @Environment(WeightDataViewModel.self) private var WeightViewModel

    @EnvironmentObject private var AppSettings: Settings

    @Binding var pageSelection: PagerSelection?

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Button {
                pageSelection?.toggle()
            } label: {
                HStack(spacing: 16) {
                    VStack(spacing: 0) {
                        Text(
                            verbatim: WeightViewModel.weightAvg7 == 0.0
                                ? "-/-"
                                : String(format: "%.1f", WeightViewModel.weightAvg7)
                        )
                            .font(.title3)
                            .foregroundStyle(pageSelection == .first ? Color("TextColor") : Color("SecondaryTextColor"))
                            .fontWeight(.semibold)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    
                        Text("Weekly")
                            .font(.caption)
                            .foregroundStyle(pageSelection == .first ? Color("TextColor") : Color("SecondaryTextColor"))
                            .fontWeight(.light)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                    .frame(minWidth: 60)
                
                    Image(systemName: "circle.slash")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color("TextColor"))
                        .rotationEffect(.degrees(-90))
                        .padding(.trailing, pageSelection == .first ? 8 : -8)
                        .padding(.leading, pageSelection == .first ? -8 : 8)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)

                    VStack(spacing: 0) {
                        Text(
                            verbatim: WeightViewModel.weightAvg30 == 0.0
                                ? "-/-"
                                : String(format: "%.1f", WeightViewModel.weightAvg30)
                        )
                            .font(.title3)
                            .foregroundStyle(pageSelection == .second ? Color("TextColor") : Color("SecondaryTextColor"))
                            .fontWeight(.semibold)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    
                        Text("Monthly")
                            .font(.caption)
                            .foregroundStyle(pageSelection == .second ? Color("TextColor") : Color("SecondaryTextColor"))
                            .fontWeight(.light)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                    .frame(minWidth: 60)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(2)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            Color("TextColor").opacity(0.2),
                            style: StrokeStyle(lineWidth: 2)
                        )

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("TextColor").opacity(0.6), style: StrokeStyle(lineWidth: 1.5))
                            .fill(Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.05))
                            .brightness(level: .secondary)
                            .frame(width: geo.size.width / 2 + 15)
                            .frame(maxWidth: .infinity, alignment: pageSelection == .first ? .leading : .trailing)
                    }
                }
            }
            .buttonStyle(.plain)
            .animation(.snappy, value: pageSelection)
            
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        Text(
                            verbatim: WeightViewModel.weightLatest == nil
                                ? "-/-"
                                : String(format: "%.1f", WeightViewModel.weightLatest!)
                        )
                            .font(.title3)
                            .foregroundStyle(Color("TextColor"))
                            .fontWeight(.semibold)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                                       
                        Text(verbatim: AppSettings.weightUnit == .lbs ? "lbs" : "kg")
                            .font(.headline)
                            .foregroundStyle(Color("SecondaryTextColor"))
                            .fontWeight(.medium)
                            .offset(y: 2)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }

                    Text(
                        WeightViewModel.weightLatestDate == nil
                            ? "Last Sample"
                            : WeightViewModel.weightLatestDate!.relative
                    )
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryTextColor"))
                        .fontWeight(.light)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                
            }
            .padding(.leading, 20)
            .padding(2)
            .padding(.vertical, 6)
            .padding(.bottom, 2)

        }
//        .padding(.leading, 13)
//        .padding(.trailing, 13)
//        .debug(.blue)
    }
    

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
