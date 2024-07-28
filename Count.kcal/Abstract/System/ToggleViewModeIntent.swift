import WidgetKit
import AppIntents

class ModeToggleManager
{
    private static let sharedDefaults: UserDefaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!
    
    static func toggle()
    {
        var buttonMode = sharedDefaults.bool(forKey: "buttonMode")
        buttonMode.toggle()
        sharedDefaults.set(buttonMode, forKey: "buttonMode")
    }
    
    static func buttonMode() -> Bool
    {
        sharedDefaults.bool(forKey: "buttonMode")
    }
}

struct ToggleViewModeIntent: AppIntent
{
    static var title: LocalizedStringResource = "Toggle widget view mode."
    static var description = IntentDescription("Switch between now and midnight modes.")
    
    func perform() async throws -> some IntentResult 
    {
        ModeToggleManager.toggle()
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

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

