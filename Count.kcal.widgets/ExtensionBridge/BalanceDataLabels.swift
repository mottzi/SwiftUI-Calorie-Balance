import SwiftUI

struct BalanceDataLabelSimple: View
{
    @Environment(\.colorScheme) var scheme: ColorScheme

    let icon: String
    let color: Color
    let label: String
    let data: Int
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            Image(systemName: "\(icon)")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .foregroundStyle(color.gradient)
                .brightness(scheme == .dark ? 0.15 : 0)
                .padding(.bottom, 4)
            
            Text("\(data)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color("TextColor"))
                .transaction { transaction in transaction.animation = .none }
            
            Text("\(label)")
                .font(.caption)
                .foregroundColor(Color("SecondaryTextColor"))
                .fontWeight(.light)
        }
        .fontDesign(.rounded)
    }
}

struct BalanceDataLabelExtra: View
{
    @Environment(\.colorScheme) var scheme: ColorScheme
    
    let icon: String
    let color: Color
    let label: String
    let dataMain: Int
    let dataTop: Int
    let dataBottom: Int
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack(spacing: 2)
            {
                Image(systemName: "\(icon)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(color.gradient)
                    .brightness(scheme == .dark ? 0.15 : 0)
                    .padding(.bottom, 4)
            }
            .offset(x: 3)
            
            Text("\(dataMain)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color("TextColor"))
                .transaction { transaction in transaction.animation = .none }
            
            Text("\(label)")
                .foregroundColor(Color("SecondaryTextColor"))
                .font(.caption)
                .fontWeight(.light)
        }
        .fontDesign(.rounded)
    }
}
