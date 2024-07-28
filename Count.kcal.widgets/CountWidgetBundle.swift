import WidgetKit
import SwiftUI

@main
struct CountWidgetBundle: WidgetBundle
{
    var body: some Widget
    {
        BalanceWidgetCircle()
        BalanceWidgetBar()
        NutritionWidget()
    }
}
