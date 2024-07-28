import WidgetKit

struct HealthDataEntry: TimelineEntry
{
    let date: Date
    let data: HealthData
}

struct HealthDataTimelineProvider: TimelineProvider
{
    func placeholder(in context: Context) -> HealthDataEntry
    {
        HealthDataEntry(date: .now, data: HealthData.example(for: .now))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HealthDataEntry) -> Void)
    {
        completion(HealthDataEntry(date: .now, data: HealthData.example(for: .now)))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthDataEntry>) -> Void)
    {
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!

//        let SharedDefaults: UserDefaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!
//             
//        // use data from phone if it is less than 60 seconds old
//        if let lastReceivedBalanceContext = SharedDefaults.object(forKey: "lastReceivedBalanceContext") as? Date
//        {
//            let interval = lastReceivedBalanceContext.timeIntervalSince(.now)
//            
//            if interval > -60 && interval <= 0
//            {
//                let data = HealthData(date: SharedDefaults.object(forKey: "date") as? Date ?? Date(timeIntervalSinceReferenceDate: 0),
//                                      burnedActive: SharedDefaults.integer(forKey: "burnedActive"),
//                                      burnedActive7: SharedDefaults.integer(forKey: "burnedActive7"),
//                                      burnedPassive: SharedDefaults.integer(forKey: "burnedPassive"),
//                                      burnedPassive7: SharedDefaults.integer(forKey: "burnedPassive7"),
//                                      consumed: SharedDefaults.integer(forKey: "consumed"),
//                                      protein: SharedDefaults.integer(forKey: "protein"),
//                                      carbs: SharedDefaults.integer(forKey: "carbs"),
//                                      fats: SharedDefaults.integer(forKey: "fats"))
//                
//                let timeline = Timeline(
//                    entries: [HealthDataEntry(date: .now, data: data)],
//                    policy: .after(nextUpdateDate)
//                )
//                
//                completion(timeline)
//                return
//            }
//        }
        
        // default: fetch from HealthKit (if received data from phone is > 60s)
        Task
        {
            let timeline = Timeline(
                entries: [HealthDataEntry(date: .now, data: try! await asyncFetchData())],
                policy: .after(nextUpdateDate)
            )
            
            completion(timeline)
        }
    }
}
