import Foundation

/// User preferences for scanning
struct ScanPreferences: Codable {
    var selectedCategories: Set<AppCategory>
    var includeSystemApps: Bool
    var minimumRatingThreshold: Double
    var checkForUpdates: Bool
    var checkSecurityRisks: Bool
    var checkPopularity: Bool
    var checkDuplicates: Bool

    static var `default`: ScanPreferences {
        ScanPreferences(
            selectedCategories: Set(AppCategory.allCases),
            includeSystemApps: true,
            minimumRatingThreshold: 3.0,
            checkForUpdates: true,
            checkSecurityRisks: true,
            checkPopularity: true,
            checkDuplicates: true
        )
    }
}
