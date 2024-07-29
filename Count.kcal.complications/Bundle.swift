import SwiftUI

@main
struct Bundle: WidgetBundle
{
    var body: some Widget
    {
        CornerBundle().body
        CircleBundle().body
        RectangleBundle().body
    }
}

struct CornerBundle: WidgetBundle
{
    var body: some Widget
    {
        BalanceCornerTextComplication()
        BalanceCornerTextMidnightComplication()
        BalanceCornerTextNowMidnightComplication()

        BalanceCornerGaugeComplication()
        BalanceCornerGaugeMidnightComplication()
    }
}

struct CircleBundle: WidgetBundle
{
    var body: some Widget
    {
        BalanceCircleGaugeComplication()
        BalanceCircleGaugeMidnightComplication()
        
        BalanceCircleGraphComplication()
        BalanceCircleGraphMidnightComplication()
        
        BalanceCircleThickGraphComplication()
        BalanceCircleThickGraphMidnightComplication()
        
        BalanceCircleFullGraphComplication()
        BalanceCircleFullGraphMidnightComplication()
    }
}

struct RectangleBundle: WidgetBundle
{
    var body: some Widget
    {
        RectangleBalanceComplication()
        RectangleBalanceMidnightComplication()
        
        RectangleBalanceBarComplication()
        RectangleBalanceBarMidnightComplication()
    }
}
