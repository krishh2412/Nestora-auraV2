import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    func requestAuthorization(keys: [String]) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "AuraHealth", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "HealthKit unavailable"])
        }

        let read = Set(keys.compactMap(Self.objectType))
        try await store.requestAuthorization(toShare: [], read: read)
    }

    func readQuantitySamples(key: String, since: Date?) async throws -> [[String: Any]] {
        guard let type = Self.objectType(key) as? HKQuantityType else { return [] }

        let predicate = since.map {
            HKQuery.predicateForSamples(withStart: $0, end: nil, options: [])
        }

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1000,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            self.store.execute(query)
        }

        return samples.map { sample in
            let (value, unit) = Self.valueAndUnit(sample, key: key)
            return [
                "sample_id": sample.uuid.uuidString,
                "metric_type": key,
                "recorded_at": ISO8601DateFormatter().string(from: sample.endDate),
                "value": value,
                "unit": unit,
                "source_bundle": sample.sourceRevision.source.bundleIdentifier
            ]
        }
    }

    static func objectType(_ key: String) -> HKObjectType? {
        switch key {
        case "steps": return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case "activeEnergy": return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case "heartRate": return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case "restingHeartRate": return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case "hrv": return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case "exerciseMinutes": return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case "weight": return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case "sleep": return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case "workouts": return HKObjectType.workoutType()
        default: return nil
        }
    }

    static func valueAndUnit(_ sample: HKQuantitySample, key: String) -> (Double, String) {
        switch key {
        case "steps":
            return (sample.quantity.doubleValue(for: .count()), "count")
        case "activeEnergy":
            return (sample.quantity.doubleValue(for: .kilocalorie()), "kcal")
        case "heartRate", "restingHeartRate":
            return (
                sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                ),
                "count/min"
            )
        case "hrv":
            return (sample.quantity.doubleValue(for: .secondUnit(with: .milli)), "ms")
        case "exerciseMinutes":
            return (sample.quantity.doubleValue(for: .minute()), "min")
        case "weight":
            return (sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), "kg")
        default:
            return (0, "")
        }
    }
}