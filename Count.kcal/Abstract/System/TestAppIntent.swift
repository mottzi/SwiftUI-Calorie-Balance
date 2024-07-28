import WidgetKit
import AppIntents

struct TestAppIntent: AppIntent 
{
    static var title: LocalizedStringResource = "Refresh widget data."
    static var description = IntentDescription("This causes widget information to update.")
    
    func perform() async throws -> some IntentResult
    {
        print("*** running AppIntent")

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

