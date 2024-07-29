import SwiftUI

struct OnboardingWelcome: View
{
    var body: some View
    {
        HStack(alignment: .bottom, spacing: 16)
        {
            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                .resizable()
                .frame(width: 70, height: 70)
                .clipShape(.rect(cornerRadius: 13))
            
            VStack(alignment: .leading, spacing: -6)
            {
                Text("Welcome to")
                    .font(.title)
                    .fontWeight(.light)
                    .opacity(0.8)
                
                Text(verbatim: "Count.kcal")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color("TextColor"))
            .fontDesign(.rounded)
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
