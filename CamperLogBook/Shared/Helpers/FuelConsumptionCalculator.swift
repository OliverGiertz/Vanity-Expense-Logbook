import Foundation

/// Calculates fuel consumption correctly, taking partial fills into account.
/// Only full fill-ups (isFull == true) end a consumption interval.
/// Liters from all entries between two full fill-ups are summed.
enum FuelConsumptionCalculator {

    /// Represents a single calculated consumption interval between two full fill-ups.
    struct Interval {
        let kmDiff: Int64
        let totalLiters: Double
        var consumptionPer100km: Double { (totalLiters / Double(kmDiff)) * 100 }
    }

    /// Calculates all valid consumption intervals from a list of fuel entries sorted ascending by date.
    /// - Parameter sortedAsc: All FuelEntry objects sorted ascending by date.
    /// - Returns: Array of Interval values, one per full-fill interval.
    static func intervals(from sortedAsc: [FuelEntry]) -> [Interval] {
        var result: [Interval] = []
        var prevFullIndex: Int? = nil

        for (index, entry) in sortedAsc.enumerated() {
            guard entry.isFull else { continue }

            if let prevIdx = prevFullIndex {
                let prevFull = sortedAsc[prevIdx]
                let kmDiff = entry.currentKm - prevFull.currentKm
                guard kmDiff > 0 else {
                    prevFullIndex = index
                    continue
                }
                // Sum liters from prevIdx+1 ... index (inclusive)
                let totalLiters = sortedAsc[(prevIdx + 1)...index].reduce(0.0) { $0 + $1.liters }
                result.append(Interval(kmDiff: kmDiff, totalLiters: totalLiters))
            }
            prevFullIndex = index
        }

        return result
    }

    /// Returns the overall average consumption across all full-fill intervals, or nil if insufficient data.
    /// - Parameter sortedAsc: All FuelEntry objects sorted ascending by date.
    static func averageConsumption(from sortedAsc: [FuelEntry]) -> Double? {
        let computed = intervals(from: sortedAsc)
        guard !computed.isEmpty else { return nil }
        let totalKm = computed.reduce(0) { $0 + $1.kmDiff }
        let totalLiters = computed.reduce(0.0) { $0 + $1.totalLiters }
        guard totalKm > 0 else { return nil }
        return (totalLiters / Double(totalKm)) * 100
    }
}
