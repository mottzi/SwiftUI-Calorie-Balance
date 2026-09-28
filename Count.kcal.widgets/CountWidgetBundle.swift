import WidgetKit
import SwiftUI

@main
/// Calorie balance and nutrition widgets available to the system.
struct CountWidgetBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidgetCircle()
        BalanceWidgetBar()
        NutritionWidget()
    }
}
