import Foundation
import Combine
import UIKit

/// Service responsible for detecting installed apps and analyzing them dynamically
final class AppAnalyzerService: ObservableObject {

    @Published var installedApps: [AppInfo] = []
    @Published var flaggedApps: [AppInfo] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanSummary: ScanSummary?

    private let networkService: NetworkService

    init(networkService: NetworkService = NetworkService()) {
        self.networkService = networkService
    }

    // MARK: - Scanning

    @MainActor
    func performScan(preferences: ScanPreferences) async {
        isScanning = true
        scanProgress = 0

        // Step 1: Detect installed apps via URL schemes
        let allKnownApps = Self.realAppDatabase()
        var detectedApps: [AppInfo] = []
        scanProgress = 0.1

        for (index, app) in allKnownApps.enumerated() {
            if isAppInstalled(app) {
                detectedApps.append(app)
            }
            if index % 10 == 0 {
                scanProgress = 0.1 + (Double(index) / Double(allKnownApps.count)) * 0.3
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
        scanProgress = 0.45

        // Step 2: Filter by selected categories
        var filteredApps = detectedApps.filter { app in
            preferences.selectedCategories.contains(app.category) &&
            (preferences.includeSystemApps || !app.isSystemApp)
        }
        scanProgress = 0.55

        // Step 3: DYNAMIC ANALYSIS - evaluate every app
        for i in filteredApps.indices {
            filteredApps[i] = analyzeApp(filteredApps[i], preferences: preferences)
            scanProgress = 0.55 + (Double(i + 1) / Double(max(filteredApps.count, 1))) * 0.25
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
        scanProgress = 0.82

        // Step 3b: Category ranking & better alternatives (cross-app analysis)
        filteredApps = assignCategoryRankings(filteredApps)
        scanProgress = 0.88

        // Step 3c: Simulate offloaded apps
        filteredApps = simulateOffloadedApps(filteredApps)
        scanProgress = 0.92

        // Sort: flagged apps first (by risk descending), then safe apps
        filteredApps.sort { a, b in
            if a.securityRisk != b.securityRisk {
                return a.securityRisk > b.securityRisk
            }
            return a.name < b.name
        }

        installedApps = filteredApps
        flaggedApps = filteredApps.filter { $0.isFlagged }
        scanProgress = 0.96

        // Step 4: Generate summary
        scanSummary = generateSummary(allApps: filteredApps, flagged: flaggedApps)
        scanProgress = 1.0

        try? await Task.sleep(nanoseconds: 500_000_000)
        isScanning = false
    }

    // MARK: - Dynamic App Analysis Engine

    /// Analyzes a single app and assigns flag reasons + security risk dynamically
    private func analyzeApp(_ app: AppInfo, preferences: ScanPreferences) -> AppInfo {
        var analyzed = app
        var reasons: [FlagReason] = []

        // --- 1. Rating Analysis ---
        if preferences.checkSecurityRisks || preferences.checkPopularity {
            if app.appStoreRating < 3.0 {
                reasons.append(.poorRating)
            }
            if app.appStoreRating < 2.5 {
                reasons.append(.negativeReviews)
            }
        }

        // --- 2. Update Freshness ---
        if preferences.checkForUpdates {
            let daysSince = app.daysSinceUpdate
            if daysSince > 365 {
                reasons.append(.noRecentUpdates)
            }
            if daysSince > 730 { // 2+ years
                reasons.append(.abandonedByDeveloper)
            }
        }

        // --- 3. Security & Privacy Analysis ---
        if preferences.checkSecurityRisks {
            let sensitivePermissions = ["Location", "Contacts", "Microphone", "Tracking", "Calendar"]
            let sensitiveCount = app.privacyPermissions.filter { sensitivePermissions.contains($0) }.count

            // Excessive permissions: more than 4 total or 3+ sensitive
            if app.privacyPermissions.count > 5 || sensitiveCount >= 3 {
                reasons.append(.excessivePermissions)
            }

            // Tracking + low rating = security concern
            if app.privacyPermissions.contains("Tracking") && app.appStoreRating < 4.0 {
                reasons.append(.securityConcerns)
            }

            // Old app + many permissions = vulnerability risk
            if app.daysSinceUpdate > 365 && app.privacyPermissions.count > 3 {
                reasons.append(.knownVulnerabilities)
            }
        }

        // --- 4. Popularity Analysis ---
        if preferences.checkPopularity {
            if app.popularityScore < 30 {
                reasons.append(.lowPopularity)
            }
        }

        // --- 5. Storage Analysis ---
        if app.sizeInMB > 500 {
            reasons.append(.highStorageUsage)
        }

        // --- 6. Duplicate Detection ---
        if preferences.checkDuplicates {
            // Check if there's a better-rated alternative in same category
            // (done within the installed apps context)
        }

        // --- 7. Usage Analysis ---
        // Simulate last used date based on app attributes
        let simulatedLastUsed = simulateLastUsedDate(for: app)
        analyzed.lastUsedDate = simulatedLastUsed

        if let lastUsed = simulatedLastUsed {
            let daysSinceUsed = Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day ?? 0
            if daysSinceUsed > 365 {
                reasons.append(.notUsedRecently)
            } else if daysSinceUsed > 180 {
                reasons.append(.rarelyUsed)
            }
        }

        // Deduplicate reasons
        var seen = Set<String>()
        reasons = reasons.filter { seen.insert($0.rawValue).inserted }

        analyzed.flagReasons = reasons

        // --- Compute Security Risk Level ---
        analyzed.securityRisk = computeRiskLevel(reasons: reasons, app: app)

        // --- Compute Deletion Recommendation ---
        analyzed.deletionRecommendation = computeDeletionRecommendation(reasons: reasons, app: analyzed)

        return analyzed
    }

    /// Simulates a last-used date based on app popularity, rating, and update frequency
    private func simulateLastUsedDate(for app: AppInfo) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // System apps are always "recently used"
        if app.isSystemApp {
            return calendar.date(byAdding: .day, value: -Int.random(in: 0...3), to: now)
        }

        // High-popularity apps are used frequently
        if app.popularityScore >= 80 {
            return calendar.date(byAdding: .day, value: -Int.random(in: 0...14), to: now)
        }

        // Medium-popularity apps used occasionally
        if app.popularityScore >= 50 {
            return calendar.date(byAdding: .day, value: -Int.random(in: 7...90), to: now)
        }

        // Low-popularity + old update = likely unused
        if app.popularityScore < 30 && app.daysSinceUpdate > 365 {
            return calendar.date(byAdding: .day, value: -Int.random(in: 365...730), to: now)
        }

        // Low-popularity but recently updated
        if app.popularityScore < 30 {
            return calendar.date(byAdding: .day, value: -Int.random(in: 60...200), to: now)
        }

        // Default: moderate usage
        return calendar.date(byAdding: .day, value: -Int.random(in: 14...120), to: now)
    }

    /// Assigns category rankings and identifies better alternatives across all apps
    private func assignCategoryRankings(_ apps: [AppInfo]) -> [AppInfo] {
        var result = apps

        // Group by category
        let grouped = Dictionary(grouping: result.indices, by: { result[$0].category })

        for (_, indices) in grouped {
            // Sort indices by rating descending
            let sorted = indices.sorted { result[$0].appStoreRating > result[$1].appStoreRating }

            for (rank, idx) in sorted.enumerated() {
                result[idx].categoryRank = rank + 1

                // If this is the lowest-rated in a category with 2+ apps, flag it
                if sorted.count >= 2 && rank == sorted.count - 1 {
                    if !result[idx].flagReasons.contains(.lowestRatedInCategory) {
                        result[idx].flagReasons.append(.lowestRatedInCategory)
                        // Recompute risk and deletion recommendation with new flag
                        result[idx].securityRisk = computeRiskLevel(reasons: result[idx].flagReasons, app: result[idx])
                        result[idx].deletionRecommendation = computeDeletionRecommendation(reasons: result[idx].flagReasons, app: result[idx])
                    }
                }

                // Identify better alternatives (higher-rated apps in same category)
                let betterIndices = sorted.prefix(rank)
                result[idx].betterAlternatives = betterIndices.map { result[$0].name }
            }
        }

        return result
    }

    /// Simulates which apps are offloaded (data removed but still on device)
    private func simulateOffloadedApps(_ apps: [AppInfo]) -> [AppInfo] {
        var result = apps
        for i in result.indices {
            // Simulate: low popularity + old + large = likely offloaded
            if !result[i].isSystemApp &&
               result[i].popularityScore < 25 &&
               result[i].daysSinceUpdate > 365 &&
               result[i].sizeInMB > 100 {
                result[i].isOffloaded = true
                if !result[i].flagReasons.contains(.offloadedUnused) {
                    result[i].flagReasons.append(.offloadedUnused)
                    result[i].securityRisk = computeRiskLevel(reasons: result[i].flagReasons, app: result[i])
                    result[i].deletionRecommendation = computeDeletionRecommendation(reasons: result[i].flagReasons, app: result[i])
                }
            }
        }
        return result
    }

    /// Computes a deletion recommendation based on flag reasons and app attributes
    private func computeDeletionRecommendation(reasons: [FlagReason], app: AppInfo) -> DeletionRecommendation {
        if reasons.isEmpty { return .keep }

        var score = 0

        for reason in reasons {
            switch reason {
            case .knownVulnerabilities: score += 4
            case .securityConcerns: score += 3
            case .abandonedByDeveloper: score += 3
            case .notUsedRecently: score += 3
            case .excessivePermissions: score += 2
            case .poorRating: score += 2
            case .negativeReviews: score += 2
            case .noRecentUpdates: score += 1
            case .rarelyUsed: score += 2
            case .lowPopularity: score += 1
            case .highStorageUsage: score += 1
            case .duplicateApp: score += 2
            case .lowestRatedInCategory: score += 2
            case .offloadedUnused: score += 3
            }
        }

        // Offloaded + unused = strongly recommend deletion
        if reasons.contains(.offloadedUnused) && reasons.contains(.notUsedRecently) {
            score += 2
        }

        // Unused + security issues = strongly recommend
        if reasons.contains(.notUsedRecently) && app.securityRisk >= .medium {
            score += 2
        }

        switch score {
        case 0: return .keep
        case 1...3: return .consider
        case 4...6: return .suggested
        default: return .stronglyRecommend
        }
    }

    /// Computes an overall security risk level based on flag reasons and app attributes
    private func computeRiskLevel(reasons: [FlagReason], app: AppInfo) -> SecurityRisk {
        if reasons.isEmpty { return .safe }

        var score = 0

        for reason in reasons {
            switch reason {
            case .knownVulnerabilities: score += 4
            case .securityConcerns: score += 3
            case .excessivePermissions: score += 3
            case .abandonedByDeveloper: score += 3
            case .poorRating: score += 2
            case .negativeReviews: score += 2
            case .noRecentUpdates: score += 2
            case .lowPopularity: score += 1
            case .highStorageUsage: score += 1
            case .duplicateApp: score += 1
            case .notUsedRecently: score += 1
            case .rarelyUsed: score += 1
            case .lowestRatedInCategory: score += 1
            case .offloadedUnused: score += 1
            }
        }

        // Extra risk for finance/banking apps with issues
        if app.category == .banking && !reasons.isEmpty {
            score += 2
        }

        // Extra risk for communication apps with security concerns
        if app.category == .communication && reasons.contains(.securityConcerns) {
            score += 2
        }

        switch score {
        case 0: return .safe
        case 1...2: return .low
        case 3...5: return .medium
        case 6...8: return .high
        default: return .critical
        }
    }

    // MARK: - App Detection

    @MainActor
    private func isAppInstalled(_ app: AppInfo) -> Bool {
        if app.isSystemApp { return true }
        if let scheme = app.urlScheme, let url = URL(string: scheme) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    // MARK: - Helpers

    func groupedByCategory() -> [AppCategory: [AppInfo]] {
        Dictionary(grouping: flaggedApps, by: \.category)
    }

    func groupedByRisk() -> [SecurityRisk: [AppInfo]] {
        Dictionary(grouping: flaggedApps, by: \.securityRisk)
    }

    func sortedByRisk() -> [AppInfo] {
        flaggedApps.sorted { $0.securityRisk > $1.securityRisk }
    }

    @MainActor
    func deleteApp(_ app: AppInfo) async -> Bool {
        flaggedApps.removeAll { $0.id == app.id }
        installedApps.removeAll { $0.id == app.id }
        if let summary = scanSummary {
            scanSummary = ScanSummary(
                totalApps: summary.totalApps - 1,
                flaggedApps: flaggedApps.count,
                securityRisks: flaggedApps.filter { $0.securityRisk >= .medium }.count,
                outdatedApps: flaggedApps.filter { $0.daysSinceUpdate > 365 }.count,
                unusedApps: installedApps.filter { $0.flagReasons.contains(.notUsedRecently) || $0.flagReasons.contains(.rarelyUsed) }.count,
                suggestedDeletions: installedApps.filter { $0.deletionRecommendation >= .suggested }.count,
                offloadedApps: installedApps.filter { $0.isOffloaded }.count,
                potentialSpaceSaved: flaggedApps.reduce(0) { $0 + $1.sizeInMB },
                categoryCounts: Dictionary(grouping: flaggedApps, by: \.category).mapValues(\.count)
            )
        }
        return true
    }

    @MainActor
    func deleteApps(_ apps: [AppInfo]) async -> Int {
        var deleted = 0
        for app in apps {
            if await deleteApp(app) { deleted += 1 }
        }
        return deleted
    }

    private func generateSummary(allApps: [AppInfo], flagged: [AppInfo]) -> ScanSummary {
        ScanSummary(
            totalApps: allApps.count,
            flaggedApps: flagged.count,
            securityRisks: flagged.filter { $0.securityRisk >= .medium }.count,
            outdatedApps: flagged.filter { $0.daysSinceUpdate > 365 }.count,
            unusedApps: allApps.filter { $0.flagReasons.contains(.notUsedRecently) || $0.flagReasons.contains(.rarelyUsed) }.count,
            suggestedDeletions: allApps.filter { $0.deletionRecommendation >= .suggested }.count,
            offloadedApps: allApps.filter { $0.isOffloaded }.count,
            potentialSpaceSaved: flagged.reduce(0) { $0 + $1.sizeInMB },
            categoryCounts: Dictionary(grouping: flagged, by: \.category).mapValues(\.count)
        )
    }

    // MARK: - Real App Database
    // All apps start with .safe / [] — the analyzer assigns flags dynamically.

    static func realAppDatabase() -> [AppInfo] {
        let calendar = Calendar.current
        let now = Date()
        func dateAgo(days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        return [
            // ===========================
            // SOCIAL MEDIA
            // ===========================
            AppInfo(id: UUID(), name: "Instagram", bundleIdentifier: "com.burbn.instagram",
                    category: .socialMedia, appStoreRating: 4.6, totalReviews: 30_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 280,
                    developerName: "Meta Platforms, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "camera.fill", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location", "Contacts"],
                    urlScheme: "instagram://"),

            AppInfo(id: UUID(), name: "Facebook", bundleIdentifier: "com.facebook.Facebook",
                    category: .socialMedia, appStoreRating: 2.2, totalReviews: 15_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 310,
                    developerName: "Meta Platforms, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "person.crop.circle.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location", "Contacts", "Tracking"],
                    urlScheme: "fb://"),

            AppInfo(id: UUID(), name: "X (Twitter)", bundleIdentifier: "com.atebits.Tweetie2",
                    category: .socialMedia, appStoreRating: 3.6, totalReviews: 8_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 220,
                    developerName: "X Corp.", securityRisk: .safe, flagReasons: [],
                    iconName: "at.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location"],
                    urlScheme: "twitter://"),

            AppInfo(id: UUID(), name: "TikTok", bundleIdentifier: "com.zhiliaoapp.musically",
                    category: .socialMedia, appStoreRating: 4.7, totalReviews: 18_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 350,
                    developerName: "TikTok Ltd.", securityRisk: .safe, flagReasons: [],
                    iconName: "music.note", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location", "Contacts", "Tracking"],
                    urlScheme: "snssdk1128://"),

            AppInfo(id: UUID(), name: "Snapchat", bundleIdentifier: "com.toyopagroup.picaboo",
                    category: .socialMedia, appStoreRating: 3.8, totalReviews: 12_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 290,
                    developerName: "Snap, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "camera.viewfinder", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location", "Contacts"],
                    urlScheme: "snapchat://"),

            AppInfo(id: UUID(), name: "LinkedIn", bundleIdentifier: "com.linkedin.LinkedIn",
                    category: .socialMedia, appStoreRating: 4.5, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 240,
                    developerName: "LinkedIn Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "link.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Contacts", "Location"],
                    urlScheme: "linkedin://"),

            AppInfo(id: UUID(), name: "Pinterest", bundleIdentifier: "pinterest",
                    category: .socialMedia, appStoreRating: 4.7, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 200,
                    developerName: "Pinterest, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "pin.circle.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "pinterest://"),

            AppInfo(id: UUID(), name: "Reddit", bundleIdentifier: "com.reddit.Reddit",
                    category: .socialMedia, appStoreRating: 4.5, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 170,
                    developerName: "Reddit, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "bubble.left.and.text.bubble.right.fill", isSystemApp: false, popularityScore: 87,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Location"],
                    urlScheme: "reddit://"),

            AppInfo(id: UUID(), name: "Threads", bundleIdentifier: "com.burbn.barcelona",
                    category: .socialMedia, appStoreRating: 3.0, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 120,
                    developerName: "Meta Platforms, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "at", isSystemApp: false, popularityScore: 70,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "barcelona://"),

            AppInfo(id: UUID(), name: "BeReal.", bundleIdentifier: "AlexisBarreyworking.BeReal",
                    category: .socialMedia, appStoreRating: 3.2, totalReviews: 1_500_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 100,
                    developerName: "BeReal", securityRisk: .safe, flagReasons: [],
                    iconName: "person.2.circle.fill", isSystemApp: false, popularityScore: 60,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Contacts", "Location"],
                    urlScheme: "bereal://"),

            // ===========================
            // COMMUNICATION
            // ===========================
            AppInfo(id: UUID(), name: "WhatsApp Messenger", bundleIdentifier: "net.whatsapp.WhatsApp",
                    category: .communication, appStoreRating: 4.7, totalReviews: 20_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 210,
                    developerName: "WhatsApp Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "phone.bubble.fill", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos", "Location"],
                    urlScheme: "whatsapp://"),

            AppInfo(id: UUID(), name: "Telegram Messenger", bundleIdentifier: "ph.telegra.Telegraph",
                    category: .communication, appStoreRating: 4.6, totalReviews: 10_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 150,
                    developerName: "Telegram FZ-LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "paperplane.fill", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos", "Location"],
                    urlScheme: "telegram://"),

            AppInfo(id: UUID(), name: "Signal - Private Messenger", bundleIdentifier: "org.whispersystems.signal",
                    category: .communication, appStoreRating: 4.7, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 130,
                    developerName: "Signal Messenger, LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "lock.shield.fill", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos"],
                    urlScheme: "sgnl://"),

            AppInfo(id: UUID(), name: "Messenger", bundleIdentifier: "com.facebook.Messenger",
                    category: .communication, appStoreRating: 2.8, totalReviews: 12_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 260,
                    developerName: "Meta Platforms, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "message.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos", "Location", "Tracking"],
                    urlScheme: "fb-messenger://"),

            AppInfo(id: UUID(), name: "Discord", bundleIdentifier: "com.hammerandchisel.discord",
                    category: .communication, appStoreRating: 4.6, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 190,
                    developerName: "Discord, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "headphones.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Photos"],
                    urlScheme: "discord://"),

            AppInfo(id: UUID(), name: "Zoom Workplace", bundleIdentifier: "us.zoom.videomeetings",
                    category: .communication, appStoreRating: 4.5, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 220,
                    developerName: "Zoom Video Communications, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "video.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Photos", "Calendar", "Contacts"],
                    urlScheme: "zoomus://"),

            AppInfo(id: UUID(), name: "Microsoft Teams", bundleIdentifier: "com.microsoft.skype.teams",
                    category: .communication, appStoreRating: 4.5, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 280,
                    developerName: "Microsoft Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "person.3.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Photos", "Contacts", "Calendar"],
                    urlScheme: "msteams://"),

            AppInfo(id: UUID(), name: "Skype", bundleIdentifier: "com.skype.skype",
                    category: .communication, appStoreRating: 4.2, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 14), sizeInMB: 200,
                    developerName: "Skype Communications S.a.r.l", securityRisk: .safe, flagReasons: [],
                    iconName: "video.circle.fill", isSystemApp: false, popularityScore: 70,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos"],
                    urlScheme: "skype://"),

            // ===========================
            // ENTERTAINMENT
            // ===========================
            AppInfo(id: UUID(), name: "YouTube", bundleIdentifier: "com.google.ios.youtube",
                    category: .entertainment, appStoreRating: 4.7, totalReviews: 25_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 270,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "play.rectangle.fill", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Photos", "Location"],
                    urlScheme: "youtube://"),

            AppInfo(id: UUID(), name: "Netflix", bundleIdentifier: "com.netflix.Netflix",
                    category: .entertainment, appStoreRating: 3.9, totalReviews: 12_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 130,
                    developerName: "Netflix, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "play.tv.fill", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "nflx://"),

            AppInfo(id: UUID(), name: "Disney+", bundleIdentifier: "com.disney.disneyplus",
                    category: .entertainment, appStoreRating: 4.6, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 180,
                    developerName: "Disney", securityRisk: .safe, flagReasons: [],
                    iconName: "sparkles.tv.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Camera"],
                    urlScheme: "disneyplus://"),

            AppInfo(id: UUID(), name: "Amazon Prime Video", bundleIdentifier: "com.amazon.aiv.AIVApp",
                    category: .entertainment, appStoreRating: 4.6, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 200,
                    developerName: "AMZN Mobile LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "play.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "aiv://"),

            AppInfo(id: UUID(), name: "Hulu", bundleIdentifier: "com.hulu.plus",
                    category: .entertainment, appStoreRating: 4.4, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 160,
                    developerName: "Hulu, LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "play.display", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: true, privacyPermissions: ["Location"],
                    urlScheme: "hulu://"),

            AppInfo(id: UUID(), name: "Max: Stream HBO, TV, & Movies", bundleIdentifier: "com.warnermedia.HBONow",
                    category: .entertainment, appStoreRating: 4.3, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 170,
                    developerName: "WarnerMedia", securityRisk: .safe, flagReasons: [],
                    iconName: "film.fill", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: true, privacyPermissions: ["Camera"],
                    urlScheme: "hbomax://"),

            AppInfo(id: UUID(), name: "Twitch: Live Game Streaming", bundleIdentifier: "tv.twitch",
                    category: .entertainment, appStoreRating: 4.3, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 190,
                    developerName: "Twitch Interactive, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "play.tv", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Photos"],
                    urlScheme: "twitch://"),

            // ===========================
            // MUSIC
            // ===========================
            AppInfo(id: UUID(), name: "Spotify", bundleIdentifier: "com.spotify.client",
                    category: .music, appStoreRating: 4.8, totalReviews: 15_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 180,
                    developerName: "Spotify AB", securityRisk: .safe, flagReasons: [],
                    iconName: "music.note.list", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone"],
                    urlScheme: "spotify://"),

            AppInfo(id: UUID(), name: "YouTube Music", bundleIdentifier: "com.google.ios.youtubemusic",
                    category: .music, appStoreRating: 4.5, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 160,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "music.note.tv.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone", "Camera"],
                    urlScheme: "youtubemusic://"),

            AppInfo(id: UUID(), name: "SoundCloud", bundleIdentifier: "com.soundcloud.TouchApp",
                    category: .music, appStoreRating: 4.6, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 140,
                    developerName: "SoundCloud Ltd.", securityRisk: .safe, flagReasons: [],
                    iconName: "waveform", isSystemApp: false, popularityScore: 78,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone"],
                    urlScheme: "soundcloud://"),

            AppInfo(id: UUID(), name: "Shazam", bundleIdentifier: "com.shazam.Shazam",
                    category: .music, appStoreRating: 4.8, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 60,
                    developerName: "Apple Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "shazam.logo.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: false, privacyPermissions: ["Microphone", "Location"],
                    urlScheme: "shazam://"),

            // ===========================
            // SHOPPING
            // ===========================
            AppInfo(id: UUID(), name: "Amazon Shopping", bundleIdentifier: "com.amazon.Amazon",
                    category: .shopping, appStoreRating: 4.7, totalReviews: 7_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 350,
                    developerName: "AMZN Mobile LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "shippingbox.fill", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location"],
                    urlScheme: "amazon://"),

            AppInfo(id: UUID(), name: "eBay: Online Marketplace", bundleIdentifier: "com.ebay.iphone",
                    category: .shopping, appStoreRating: 4.7, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 220,
                    developerName: "eBay Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "tag.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location"],
                    urlScheme: "ebay://"),

            AppInfo(id: UUID(), name: "Walmart", bundleIdentifier: "com.walmart.electronics",
                    category: .shopping, appStoreRating: 4.8, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 250,
                    developerName: "Walmart Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "cart.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location"],
                    urlScheme: "walmart://"),

            AppInfo(id: UUID(), name: "SHEIN", bundleIdentifier: "com.zzkko.shein",
                    category: .shopping, appStoreRating: 4.6, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 300,
                    developerName: "SHEIN Group Ltd", securityRisk: .safe, flagReasons: [],
                    iconName: "bag.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location", "Contacts", "Tracking"],
                    urlScheme: "shein://"),

            AppInfo(id: UUID(), name: "Temu", bundleIdentifier: "com.einnovation.temu",
                    category: .shopping, appStoreRating: 4.6, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 280,
                    developerName: "Whaleco Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "gift.fill", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location", "Contacts", "Tracking"],
                    urlScheme: "temu://"),

            AppInfo(id: UUID(), name: "Etsy", bundleIdentifier: "com.etsy.etsyforios",
                    category: .shopping, appStoreRating: 4.8, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 160,
                    developerName: "Etsy, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "paintbrush.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location"],
                    urlScheme: "etsy://"),

            // ===========================
            // FOOD & DRINK
            // ===========================
            AppInfo(id: UUID(), name: "DoorDash - Food Delivery", bundleIdentifier: "com.doordash.DoorDash",
                    category: .foodDrink, appStoreRating: 4.7, totalReviews: 5_500_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 250,
                    developerName: "DoorDash, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "takeoutbag.and.cup.and.straw.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera"],
                    urlScheme: "doordash://"),

            AppInfo(id: UUID(), name: "Uber Eats: Food Delivery", bundleIdentifier: "com.ubercab.UberEats",
                    category: .foodDrink, appStoreRating: 4.7, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 280,
                    developerName: "Uber Technologies, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "fork.knife.circle.fill", isSystemApp: false, popularityScore: 93,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera", "Photos"],
                    urlScheme: "ubereats://"),

            AppInfo(id: UUID(), name: "Starbucks", bundleIdentifier: "com.starbucks.mystarbucks",
                    category: .foodDrink, appStoreRating: 4.8, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 200,
                    developerName: "Starbucks Coffee Company", securityRisk: .safe, flagReasons: [],
                    iconName: "cup.and.saucer.fill", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera"],
                    urlScheme: "starbucks://"),

            AppInfo(id: UUID(), name: "McDonald's", bundleIdentifier: "com.mcdonalds.mobileapp",
                    category: .foodDrink, appStoreRating: 4.7, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 180,
                    developerName: "McDonald's", securityRisk: .safe, flagReasons: [],
                    iconName: "menucard.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera"],
                    urlScheme: "mcd://"),

            AppInfo(id: UUID(), name: "Grubhub: Food Delivery", bundleIdentifier: "com.grubhub.iphone",
                    category: .foodDrink, appStoreRating: 4.7, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 200,
                    developerName: "GrubHub Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "bicycle", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera"],
                    urlScheme: "grubhub://"),

            // ===========================
            // TRAVEL
            // ===========================
            AppInfo(id: UUID(), name: "Uber", bundleIdentifier: "com.ubercab.UberClient",
                    category: .travel, appStoreRating: 4.7, totalReviews: 10_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 360,
                    developerName: "Uber Technologies, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "car.fill", isSystemApp: false, popularityScore: 97,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera", "Contacts"],
                    urlScheme: "uber://"),

            AppInfo(id: UUID(), name: "Lyft", bundleIdentifier: "com.zimride.instant",
                    category: .travel, appStoreRating: 4.8, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 290,
                    developerName: "Lyft, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "car.2.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Contacts"],
                    urlScheme: "lyft://"),

            AppInfo(id: UUID(), name: "Airbnb", bundleIdentifier: "com.airbnb.app",
                    category: .travel, appStoreRating: 4.7, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 320,
                    developerName: "Airbnb, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "house.fill", isSystemApp: false, popularityScore: 94,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera", "Photos"],
                    urlScheme: "airbnb://"),

            AppInfo(id: UUID(), name: "Google Maps", bundleIdentifier: "com.google.Maps",
                    category: .travel, appStoreRating: 4.7, totalReviews: 8_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 300,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "map.fill", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera", "Microphone"],
                    urlScheme: "comgooglemaps://"),

            AppInfo(id: UUID(), name: "Waze Navigation", bundleIdentifier: "com.waze.iphone",
                    category: .travel, appStoreRating: 4.8, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 250,
                    developerName: "Waze Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "location.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Microphone", "Contacts"],
                    urlScheme: "waze://"),

            // ===========================
            // BANKING & FINANCE
            // ===========================
            AppInfo(id: UUID(), name: "PayPal", bundleIdentifier: "com.yourcompany.PPClient",
                    category: .banking, appStoreRating: 4.8, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 250,
                    developerName: "PayPal, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "creditcard.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Location", "Contacts"],
                    urlScheme: "paypal://"),

            AppInfo(id: UUID(), name: "Venmo", bundleIdentifier: "com.venmo.Venmo",
                    category: .banking, appStoreRating: 4.8, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 200,
                    developerName: "PayPal, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "dollarsign.circle.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Contacts", "Location"],
                    urlScheme: "venmo://"),

            AppInfo(id: UUID(), name: "Cash App", bundleIdentifier: "com.squareup.cash",
                    category: .banking, appStoreRating: 4.7, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 180,
                    developerName: "Block, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "banknote.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Contacts", "Location"],
                    urlScheme: "cashme://"),

            AppInfo(id: UUID(), name: "Robinhood", bundleIdentifier: "com.robinhood.release",
                    category: .banking, appStoreRating: 4.2, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 200,
                    developerName: "Robinhood Markets, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "chart.line.uptrend.xyaxis.circle.fill", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: false, privacyPermissions: ["Camera"],
                    urlScheme: "robinhood://"),

            AppInfo(id: UUID(), name: "Coinbase", bundleIdentifier: "com.coinbase.Coinbase",
                    category: .banking, appStoreRating: 4.5, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 160,
                    developerName: "Coinbase, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "bitcoinsign.circle.fill", isSystemApp: false, popularityScore: 78,
                    hasInAppPurchases: false, privacyPermissions: ["Camera"],
                    urlScheme: "coinbase://"),

            // ===========================
            // PRODUCTIVITY
            // ===========================
            AppInfo(id: UUID(), name: "Gmail", bundleIdentifier: "com.google.Gmail",
                    category: .productivity, appStoreRating: 4.2, totalReviews: 8_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 300,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "envelope.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Contacts"],
                    urlScheme: "googlegmail://"),

            AppInfo(id: UUID(), name: "Google Drive", bundleIdentifier: "com.google.Drive",
                    category: .productivity, appStoreRating: 4.6, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 250,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "externaldrive.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "googledrive://"),

            AppInfo(id: UUID(), name: "Microsoft Outlook", bundleIdentifier: "com.microsoft.Office.Outlook",
                    category: .productivity, appStoreRating: 4.7, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 350,
                    developerName: "Microsoft Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "tray.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Contacts", "Calendar"],
                    urlScheme: "ms-outlook://"),

            AppInfo(id: UUID(), name: "Notion", bundleIdentifier: "notion.id",
                    category: .productivity, appStoreRating: 4.8, totalReviews: 1_500_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 180,
                    developerName: "Notion Labs, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "square.grid.2x2.fill", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "notion://"),

            AppInfo(id: UUID(), name: "Slack", bundleIdentifier: "com.tinyspeck.chatlyio",
                    category: .productivity, appStoreRating: 4.5, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 240,
                    developerName: "Slack Technologies, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "number.square.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Photos"],
                    urlScheme: "slack://"),

            AppInfo(id: UUID(), name: "Google Docs", bundleIdentifier: "com.google.Docs",
                    category: .productivity, appStoreRating: 4.2, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 220,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "doc.text.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "googledocs://"),

            AppInfo(id: UUID(), name: "Microsoft Word", bundleIdentifier: "com.microsoft.Office.Word",
                    category: .productivity, appStoreRating: 4.7, totalReviews: 2_800_000,
                    lastUpdated: dateAgo(days: 14), sizeInMB: 420,
                    developerName: "Microsoft Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "doc.richtext.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "ms-word://"),

            // ===========================
            // GAMES
            // ===========================
            AppInfo(id: UUID(), name: "Roblox", bundleIdentifier: "com.roblox.robloxmobile",
                    category: .games, appStoreRating: 4.4, totalReviews: 8_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 500,
                    developerName: "Roblox Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "cube.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "robloxmobile://"),

            AppInfo(id: UUID(), name: "Candy Crush Saga", bundleIdentifier: "com.king.candycrushsaga",
                    category: .games, appStoreRating: 4.6, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 350,
                    developerName: "King", securityRisk: .safe, flagReasons: [],
                    iconName: "circle.hexagongrid.fill", isSystemApp: false, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Tracking"],
                    urlScheme: "candycrushsaga://"),

            AppInfo(id: UUID(), name: "Subway Surfers", bundleIdentifier: "com.kiloo.SubwaySurfers",
                    category: .games, appStoreRating: 4.5, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 310,
                    developerName: "SYBO Games ApS", securityRisk: .safe, flagReasons: [],
                    iconName: "figure.run", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: true, privacyPermissions: ["Tracking"],
                    urlScheme: "subwaysurfers://"),

            AppInfo(id: UUID(), name: "Among Us!", bundleIdentifier: "com.innersloth.amongus",
                    category: .games, appStoreRating: 4.4, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 14), sizeInMB: 270,
                    developerName: "InnerSloth LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "person.fill.questionmark", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: true, privacyPermissions: [],
                    urlScheme: "amongus://"),

            AppInfo(id: UUID(), name: "Call of Duty: Mobile", bundleIdentifier: "com.activision.callofduty.shooter",
                    category: .games, appStoreRating: 4.6, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 2500,
                    developerName: "Activision Publishing, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "scope", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "codmobile://"),

            AppInfo(id: UUID(), name: "PUBG MOBILE", bundleIdentifier: "com.tencent.ig",
                    category: .games, appStoreRating: 4.2, totalReviews: 3_500_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 2800,
                    developerName: "Level Infinite", securityRisk: .safe, flagReasons: [],
                    iconName: "target", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone", "Location", "Tracking"],
                    urlScheme: "pubgmobile://"),

            // ===========================
            // PHOTOGRAPHY
            // ===========================
            AppInfo(id: UUID(), name: "VSCO", bundleIdentifier: "com.vsco.vsco",
                    category: .photography, appStoreRating: 4.5, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 9), sizeInMB: 160,
                    developerName: "Visual Supply Company", securityRisk: .safe, flagReasons: [],
                    iconName: "camera.filters", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "vsco://"),

            AppInfo(id: UUID(), name: "Snapseed", bundleIdentifier: "com.google.Snapseed",
                    category: .photography, appStoreRating: 4.5, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 60), sizeInMB: 110,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "wand.and.stars", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "snapseed://"),

            AppInfo(id: UUID(), name: "Lightroom Photo & Video Editor", bundleIdentifier: "com.adobe.lrmobilephone",
                    category: .photography, appStoreRating: 4.7, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 280,
                    developerName: "Adobe Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "slider.horizontal.3", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"],
                    urlScheme: "adobelightroom://"),

            // ===========================
            // HEALTH & FITNESS
            // ===========================
            AppInfo(id: UUID(), name: "MyFitnessPal: Calorie Counter", bundleIdentifier: "com.myfitnesspal.mfp",
                    category: .healthFitness, appStoreRating: 4.6, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 12), sizeInMB: 210,
                    developerName: "MyFitnessPal, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "heart.text.square.fill", isSystemApp: false, popularityScore: 91,
                    hasInAppPurchases: true, privacyPermissions: ["HealthKit", "Camera"],
                    urlScheme: "myfitnesspal://"),

            AppInfo(id: UUID(), name: "Nike Run Club", bundleIdentifier: "com.nike.nikeplus-gps",
                    category: .healthFitness, appStoreRating: 4.7, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 200,
                    developerName: "Nike, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "figure.run.circle.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: false, privacyPermissions: ["HealthKit", "Location"],
                    urlScheme: "nikerunclub://"),

            AppInfo(id: UUID(), name: "Strava: Run, Ride, Hike", bundleIdentifier: "com.strava.stravaride",
                    category: .healthFitness, appStoreRating: 4.6, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 190,
                    developerName: "Strava, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "figure.hiking", isSystemApp: false, popularityScore: 83,
                    hasInAppPurchases: true, privacyPermissions: ["HealthKit", "Location", "Camera", "Photos"],
                    urlScheme: "strava://"),

            AppInfo(id: UUID(), name: "Fitbit", bundleIdentifier: "com.fitbit.FitbitMobile",
                    category: .healthFitness, appStoreRating: 3.8, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 220,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "heart.circle.fill", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: true, privacyPermissions: ["HealthKit", "Location", "Camera"],
                    urlScheme: "fitbit://"),

            // ===========================
            // EDUCATION
            // ===========================
            AppInfo(id: UUID(), name: "Duolingo", bundleIdentifier: "com.duolingo.DuolingoMobile",
                    category: .education, appStoreRating: 4.7, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 190,
                    developerName: "Duolingo, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "character.book.closed.fill", isSystemApp: false, popularityScore: 96,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone"],
                    urlScheme: "duolingo://"),

            AppInfo(id: UUID(), name: "Quizlet", bundleIdentifier: "com.quizlet.quizlet",
                    category: .education, appStoreRating: 4.7, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 140,
                    developerName: "Quizlet Inc", securityRisk: .safe, flagReasons: [],
                    iconName: "rectangle.stack.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "quizlet://"),

            AppInfo(id: UUID(), name: "Canvas Student", bundleIdentifier: "com.instructure.icanvas",
                    category: .education, appStoreRating: 4.2, totalReviews: 1_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 140,
                    developerName: "Instructure Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "graduationcap.fill", isSystemApp: false, popularityScore: 75,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Microphone"],
                    urlScheme: "canvas-student://"),

            // ===========================
            // NEWS & MAGAZINES
            // ===========================
            AppInfo(id: UUID(), name: "Google News", bundleIdentifier: "com.google.GoogleNewsiOSApp",
                    category: .news, appStoreRating: 4.5, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 130,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "newspaper.fill", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: false, privacyPermissions: ["Location"],
                    urlScheme: "googlenews://"),

            AppInfo(id: UUID(), name: "Flipboard", bundleIdentifier: "com.flipboard.flipboard-ipad",
                    category: .news, appStoreRating: 4.7, totalReviews: 1_500_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 120,
                    developerName: "Flipboard, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "book.fill", isSystemApp: false, popularityScore: 75,
                    hasInAppPurchases: true, privacyPermissions: ["Contacts"],
                    urlScheme: "flipboard://"),

            // ===========================
            // SPORTS
            // ===========================
            AppInfo(id: UUID(), name: "ESPN: Live Sports & Scores", bundleIdentifier: "com.espn.ScoreCenter",
                    category: .sports, appStoreRating: 4.6, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 250,
                    developerName: "ESPN Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "sportscourt.fill", isSystemApp: false, popularityScore: 93,
                    hasInAppPurchases: true, privacyPermissions: ["Location"],
                    urlScheme: "espn://"),

            AppInfo(id: UUID(), name: "NBA: Live Games & Scores", bundleIdentifier: "com.nba.gametime",
                    category: .sports, appStoreRating: 4.5, totalReviews: 1_500_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 180,
                    developerName: "NBA Properties, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "basketball.fill", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: true, privacyPermissions: ["Location"],
                    urlScheme: "gametime://"),

            // ===========================
            // WEATHER
            // ===========================
            AppInfo(id: UUID(), name: "The Weather Channel", bundleIdentifier: "com.weather.TWC",
                    category: .weather, appStoreRating: 4.7, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 180,
                    developerName: "The Weather Channel", securityRisk: .safe, flagReasons: [],
                    iconName: "cloud.sun.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Location"],
                    urlScheme: "twcweather://"),

            AppInfo(id: UUID(), name: "AccuWeather", bundleIdentifier: "com.accuweather.iphone",
                    category: .weather, appStoreRating: 4.5, totalReviews: 2_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 150,
                    developerName: "AccuWeather International, Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "thermometer.sun.fill", isSystemApp: false, popularityScore: 78,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Tracking"],
                    urlScheme: "accuweather://"),

            // ===========================
            // UTILITIES
            // ===========================
            AppInfo(id: UUID(), name: "Google Chrome", bundleIdentifier: "com.google.chrome.ios",
                    category: .utilities, appStoreRating: 4.2, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 220,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "globe", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Location"],
                    urlScheme: "googlechrome://"),

            AppInfo(id: UUID(), name: "Google", bundleIdentifier: "com.google.GoogleMobile",
                    category: .utilities, appStoreRating: 4.3, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 340,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "magnifyingglass.circle.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Location"],
                    urlScheme: "googleapp://"),

            AppInfo(id: UUID(), name: "Google Translate", bundleIdentifier: "com.google.Translate",
                    category: .utilities, appStoreRating: 4.5, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 180,
                    developerName: "Google LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "character.bubble.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone"],
                    urlScheme: "googletranslate://"),

            AppInfo(id: UUID(), name: "1Password", bundleIdentifier: "com.agilebits.onepassword-ios",
                    category: .utilities, appStoreRating: 4.7, totalReviews: 1_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 140,
                    developerName: "AgileBits Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "lock.fill", isSystemApp: false, popularityScore: 82,
                    hasInAppPurchases: true, privacyPermissions: ["Camera"],
                    urlScheme: "onepassword://"),

            // ===========================
            // LIFESTYLE
            // ===========================
            AppInfo(id: UUID(), name: "Tinder", bundleIdentifier: "com.cardify.tinder",
                    category: .lifestyle, appStoreRating: 3.5, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 240,
                    developerName: "Tinder Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "flame.fill", isSystemApp: false, popularityScore: 85,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Location", "Contacts"],
                    urlScheme: "tinder://"),

            AppInfo(id: UUID(), name: "Bumble", bundleIdentifier: "com.mosaic.bumble",
                    category: .lifestyle, appStoreRating: 4.1, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 200,
                    developerName: "Bumble Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "heart.circle.fill", isSystemApp: false, popularityScore: 80,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Location", "Contacts"],
                    urlScheme: "bumble://"),

            // ===========================
            // BUSINESS
            // ===========================
            AppInfo(id: UUID(), name: "Indeed Job Search", bundleIdentifier: "com.indeed.IndeedApp",
                    category: .business, appStoreRating: 4.8, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 160,
                    developerName: "Indeed Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "briefcase.fill", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: false, privacyPermissions: ["Location"],
                    urlScheme: "indeed://"),
        ]
    }
}
