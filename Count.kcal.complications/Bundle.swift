import SwiftUI
import WidgetKit

@main
struct Bundle: WidgetBundle {

    var body: some Widget {
        CornerBundle().body
        CircleBundle().body
        RectangleBundle().body
        GoalBundle().body
    }

}

struct GoalBundle: WidgetBundle {

    var body: some Widget {
        CalorieRoomComplication()
        MacroGoalsComplication()
        StepGoalComplication()
    }

}

struct CornerBundle: WidgetBundle {

    var body: some Widget {
        BalanceCornerTextComplication<NowComplicationMode>()
        BalanceCornerTextComplication<MidnightComplicationMode>()
        BalanceCornerTextNowMidnightComplication()

        BalanceCornerGaugeComplication<NowComplicationMode>()
        BalanceCornerGaugeComplication<MidnightComplicationMode>()
    }

}

struct CircleBundle: WidgetBundle {

    var body: some Widget {
        BalanceCircleGaugeComplication<NowComplicationMode>()
        BalanceCircleGaugeComplication<MidnightComplicationMode>()
        
        BalanceCircleGraphComplication<NowComplicationMode>()
        BalanceCircleGraphComplication<MidnightComplicationMode>()
        
        BalanceCircleThickGraphComplication<NowComplicationMode>()
        BalanceCircleThickGraphComplication<MidnightComplicationMode>()
        
        BalanceCircleFullGraphComplication<NowComplicationMode>()
        BalanceCircleFullGraphComplication<MidnightComplicationMode>()
    }

}

struct RectangleBundle: WidgetBundle {

    var body: some Widget {
        RectangleBalanceComplication<NowComplicationMode>()
        RectangleBalanceComplication<MidnightComplicationMode>()
        
        RectangleBalanceBarComplication<NowComplicationMode>()
        RectangleBalanceBarComplication<MidnightComplicationMode>()
    }

}

/// Fixed balance mode for one registered complication type.
protocol BalanceComplicationMode {

    static var graphMode: GraphMode { get }

}

/// Current balance mode for a complication registration.
enum NowComplicationMode: BalanceComplicationMode {

    static var graphMode: GraphMode { .now }

}

/// Midnight balance mode for a complication registration.
enum MidnightComplicationMode: BalanceComplicationMode {

    static var graphMode: GraphMode { .midnight }

}
