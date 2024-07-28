protocol GraphCalculations
{
    var AppSettings: Settings { get }
    var DataInterface: HealthInterface { get }
    var mode: GraphMode { get }
    var passiveFuture: Int { get }
    var maxNow: Int { get }
    var maxMidnight: Int { get }
    var activeNow: Double { get }
    var passiveNow: Double { get }
    var consumedNow: Double { get }
    var activeMidnight: Double { get }
    var passiveMidnight: Double { get }
    var passiveFutureMidnight: Double { get }
    var consumedMidnight: Double { get }
}

extension GraphCalculations
{
    var passiveFuture: Int
    {
        mode == .midnight ? max(DataInterface.sample.burnedPassive7 - DataInterface.sample.burnedPassive, 0) : 0
    }

    var maxNow: Int
    {
        max(DataInterface.sample.burnedActive + DataInterface.sample.burnedPassive, DataInterface.sample.consumed)
    }

    var maxMidnight: Int
    {
        max((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive + passiveFuture, DataInterface.sample.consumed)
    }

    var activeNow: Double
    {
        maxNow == 0 ? 0.0 : Double(DataInterface.sample.burnedActive) / Double(maxNow)
    }

    var passiveNow: Double
    {
        maxNow == 0 ? 0.0 : Double(DataInterface.sample.burnedActive + DataInterface.sample.burnedPassive) / Double(maxNow)
    }

    var consumedNow: Double
    {
        maxNow == 0 ? 0.0 : Double(DataInterface.sample.consumed) / Double(maxNow)
    }

    var activeMidnight: Double
    {
        maxMidnight == 0 ? 0.0 : (AppSettings.dataSource == .apple ? Double(DataInterface.sample.burnedActive) : Double(DataInterface.sample.burnedActive7)) / Double(maxMidnight)
    }

    var passiveMidnight: Double
    {
        maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive) / Double(maxMidnight)
    }

    var passiveFutureMidnight: Double
    {
        maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive + passiveFuture) / Double(maxMidnight)
    }

    var consumedMidnight: Double
    {
        maxMidnight == 0 ? 0.0 : Double(DataInterface.sample.consumed) / Double(maxMidnight)
    }
}


//    var passiveFuture: Int { Mode == .midnight ? max(DataInterface.sample.burnedPassive7 - DataInterface.sample.burnedPassive, 0) : 0 }
//
//    var maxNow: Int { max(DataInterface.sample.burnedActive + DataInterface.sample.burnedPassive, DataInterface.sample.consumed) }
//    var maxMidnight: Int { max((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive + passiveFuture, DataInterface.sample.consumed) }
//
//    var activeNow: Double { maxNow == 0 ? 0.0 : Double(DataInterface.sample.burnedActive) / Double(maxNow) }
//    var passiveNow: Double { maxNow == 0 ? 0.0 : Double(DataInterface.sample.burnedActive + DataInterface.sample.burnedPassive) / Double(maxNow) }
//    var consumedNow: Double { maxNow == 0 ? 0.0 : Double(DataInterface.sample.consumed) / Double(maxNow) }
//
//    var activeMidnight: Double { maxMidnight == 0 ? 0.0 : (AppSettings.dataSource == .apple ? Double(DataInterface.sample.burnedActive) : Double(DataInterface.sample.burnedActive7)) / Double(maxMidnight) }
//    var passiveMidnight: Double { maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive) / Double(maxMidnight) }
//    var passiveFutureMidnight: Double { maxMidnight == 0 ? 0.0 : Double((AppSettings.dataSource == .apple ? DataInterface.sample.burnedActive : DataInterface.sample.burnedActive7) + DataInterface.sample.burnedPassive + passiveFuture) / Double(maxMidnight) }
//    var consumedMidnight: Double { maxMidnight == 0 ? 0.0 : Double(DataInterface.sample.consumed) / Double(maxMidnight) }
