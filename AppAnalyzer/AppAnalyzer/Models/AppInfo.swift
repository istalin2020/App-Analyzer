import Foundation
import SwiftUI

/// Security risk level for an app
enum SecurityRisk: String, Codable, Comparable {
    case safe = "Safe"
    case low = "Low Risk"
    case medium = "Medium Risk"
    case high = "High Risk"
    case critical = "Critical Risk"

    var color: Color {
        switch self {
        case .safe: return .green
        case .low: return .mint
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .low: return "shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high: return "xmark.shield.fill"
        case .critical: return "shield.slash.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    static func < (lhs: SecurityRisk, rhs: SecurityRisk) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Reason why an app is flagged
enum FlagReason: String, Codable, Identifiable {
    case poorRating = "Poor App Store Rating"
    case noRecentUpdates = "No Recent Updates"
    case securityConcerns = "Security Concerns Reported"
    case lowPopularity = "Low Popularity"
    case duplicateApp = "Duplicate Functionality"
    case highStorageUsage = "High Storage Usage"
    case excessivePermissions = "Excessive Permissions"
    case negativeReviews = "Negative User Reviews"
    case abandonedByDeveloper = "Abandoned by Developer"
    case knownVulnerabilities = "Known Vulnerabilities"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .poorRating: return "star.slash.fill"
        case .noRecentUpdates: return "clock.badge.exclamationmark"
        case .securityConcerns: return "lock.slash.fill"
        case .lowPopularity: return "person.slash.fill"
        case .duplicateApp: return "doc.on.doc.fill"
        case .highStorageUsage: return "externaldrive.fill.badge.exclamationmark"
        case .excessivePermissions: return "hand.raised.slash.fill"
        case .negativeReviews: return "hand.thumbsdown.fill"
        case .abandonedByDeveloper: return "xmark.bin.fill"
        case .knownVulnerabilities: return "ladybug.fill"
        }
    }

    var color: Color {
        switch self {
        case .poorRating: return .orange
        case .noRecentUpdates: return .yellow
        case .securityConcerns: return .red
        case .lowPopularity: return .gray
        case .duplicateApp: return .blue
        case .highStorageUsage: return .purple
        case .excessivePermissions: return .red
        case .negativeReviews: return .orange
        case .abandonedByDeveloper: return .brown
        case .knownVulnerabilities: return .red
        }
    }
}

/// Represents an installed app with analysis data
struct AppInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let category: AppCategory
    let appStoreRating: Double
    let totalReviews: Int
    let lastUpdated: Date
    let sizeInMB: Double
    let developerName: String
    let securityRisk: SecurityRisk
    let flagReasons: [FlagReason]
    let iconName: String
    let isSystemApp: Bool
    let popularityScore: Int // 1-100
    let hasInAppPurchases: Bool
    let privacyPermissions: [String]
    let urlScheme: String? // URL scheme used to detect if app is installed

    var isFlagged: Bool {
        !flagReasons.isEmpty
    }

    var daysSinceUpdate: Int {
        Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
    }

    var ratingStars: String {
        let fullStars = Int(appStoreRating)
        let hasHalf = appStoreRating - Double(fullStars) >= 0.5
        var result = String(repeating: "★", count: fullStars)
        if hasHalf { result += "½" }
        result += String(repeating: "☆", count: 5 - fullStars - (hasHalf ? 1 : 0))
        return result
    }

    var formattedSize: String {
        if sizeInMB >= 1024 {
            return String(format: "%.1f GB", sizeInMB / 1024)
        }
        return String(format: "%.0f MB", sizeInMB)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Summary of scan results
struct ScanSummary {
    let totalApps: Int
    let flaggedApps: Int
    let securityRisks: Int
    let outdatedApps: Int
    let potentialSpaceSaved: Double
    let categoryCounts: [AppCategory: Int]

    var formattedSpaceSaved: String {
        if potentialSpaceSaved >= 1024 {
            return String(format: "%.1f GB", potentialSpaceSaved / 1024)
        }
        return String(format: "%.0f MB", potentialSpaceSaved)
    }
}
