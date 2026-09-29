import SwiftUI

struct OnboardingWelcome: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        (dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 16))) {
            Image("icon")
                .resizable()
                .frame(width: dynamicType.isAccessibilitySize ? 56 : 70,
                       height: dynamicType.isAccessibilitySize ? 56 : 70)
            
            VStack(alignment: .leading, spacing: dynamicType.isAccessibilitySize ? 0 : -6) {
                Text("Welcome to")
                    .font(.title)
                    .fontWeight(.light)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(verbatim: "Count.kcal")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Color("TextColor"))
            .fontDesign(.rounded)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .frame(maxWidth: dynamicType.isAccessibilitySize ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, dynamicType.isAccessibilitySize ? 24 : 0)
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightHistory())
    .environment(Streak())
}
