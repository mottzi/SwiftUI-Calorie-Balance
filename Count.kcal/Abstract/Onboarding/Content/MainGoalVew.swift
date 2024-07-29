import SwiftUI

struct MaingoalView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.colorScheme) private var scheme: ColorScheme
    
    var body: some View
    {
        VStack(spacing: 30)
        {
            (
                Text("My")
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                    .fontWeight(.light)
                +
                Text(verbatim: " ")
                +
                Text("goal")
                +
                Text(verbatim: " ")
                +
                Text("is to ...")
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                    .fontWeight(.light)
            )
            .font(.title)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundStyle(Color("TextColor").gradient)
            
            IconPicker(firstIcon: "arrowshape.down.fill", secondIcon: "arrowshape.up.fill", selection: $AppSettings.weightGoal)
                .frame(width: 120, height: 40)
                .scaleEffect(1.4)
                .sensoryFeedback(.selection, trigger: AppSettings.weightGoal)
            
            Text(AppSettings.weightGoal == .lose ? "Lose Weight" : "Gain Weight")
                .font(.title)
                .fontWeight(.semibold)
                .animation(.linear, value: AppSettings.weightGoal)
                .fontDesign(.rounded)
                .foregroundStyle(Color("TextColor"))
        }
    }
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightDataViewModel())
    .environment(Streak())
}
