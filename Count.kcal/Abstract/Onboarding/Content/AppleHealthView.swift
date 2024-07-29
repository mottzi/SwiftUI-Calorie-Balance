import SwiftUI

struct AppleHealthView: View
{
    @EnvironmentObject private var AppSettings: Settings
    
    var body: some View
    {
        VStack(spacing: 16)
        {
            Image("Health")
                .resizable()
                .frame(width: 90, height: 90)
            
            VStack(spacing: -4)
            {
                Text("Allow access to")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundStyle(Color("TextColor").opacity(0.8))
                
                Text(verbatim: "Apple Health")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextColor").gradient)
            }
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
