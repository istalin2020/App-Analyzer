import Foundation
import Combine

/// Service responsible for analyzing installed apps and generating recommendations
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

    /// Performs a full scan of installed apps based on user preferences
    @MainActor
    func performScan(preferences: ScanPreferences) async {
        isScanning = true
        scanProgress = 0

        // Step 1: Discover installed apps
        let allApps = await discoverInstalledApps()
        scanProgress = 0.3

        // Step 2: Filter by selected categories
        let filteredApps = allApps.filter { app in
            preferences.selectedCategories.contains(app.category) &&
            (preferences.includeSystemApps || !app.isSystemApp)
        }
        installedApps = filteredApps
        scanProgress = 0.5

        // Step 3: Analyze each app for issues
        var flagged: [AppInfo] = []
        for (index, app) in filteredApps.enumerated() {
            if app.isFlagged {
                flagged.append(app)
            }
            scanProgress = 0.5 + (Double(index + 1) / Double(filteredApps.count)) * 0.4
            // Small delay for smooth progress animation
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        flaggedApps = flagged
        scanProgress = 0.95

        // Step 4: Generate summary
        scanSummary = generateSummary(allApps: filteredApps, flagged: flagged)
        scanProgress = 1.0

        // Brief pause to show completion
        try? await Task.sleep(nanoseconds: 500_000_000)
        isScanning = false
    }

    /// Groups flagged apps by category
    func groupedByCategory() -> [AppCategory: [AppInfo]] {
        Dictionary(grouping: flaggedApps, by: \.category)
    }

    /// Groups flagged apps by security risk
    func groupedByRisk() -> [SecurityRisk: [AppInfo]] {
        Dictionary(grouping: flaggedApps, by: \.securityRisk)
    }

    /// Sorts flagged apps by risk level (highest first)
    func sortedByRisk() -> [AppInfo] {
        flaggedApps.sorted { $0.securityRisk > $1.securityRisk }
    }

    /// Removes an app from the flagged list (simulates deletion)
    @MainActor
    func deleteApp(_ app: AppInfo) async -> Bool {
        // In production, this would use private APIs or direct the user
        // to iOS Settings for actual app removal. For security, we simulate
        // the process and provide a deep link to Settings.
        flaggedApps.removeAll { $0.id == app.id }
        installedApps.removeAll { $0.id == app.id }

        // Update summary
        if let summary = scanSummary {
            scanSummary = ScanSummary(
                totalApps: summary.totalApps - 1,
                flaggedApps: flaggedApps.count,
                securityRisks: flaggedApps.filter { $0.securityRisk >= .medium }.count,
                outdatedApps: flaggedApps.filter { $0.daysSinceUpdate > 365 }.count,
                potentialSpaceSaved: flaggedApps.reduce(0) { $0 + $1.sizeInMB },
                categoryCounts: Dictionary(grouping: flaggedApps, by: \.category).mapValues(\.count)
            )
        }
        return true
    }

    /// Bulk delete selected apps
    @MainActor
    func deleteApps(_ apps: [AppInfo]) async -> Int {
        var deleted = 0
        for app in apps {
            if await deleteApp(app) {
                deleted += 1
            }
        }
        return deleted
    }

    // MARK: - Private

    private func generateSummary(allApps: [AppInfo], flagged: [AppInfo]) -> ScanSummary {
        ScanSummary(
            totalApps: allApps.count,
            flaggedApps: flagged.count,
            securityRisks: flagged.filter { $0.securityRisk >= .medium }.count,
            outdatedApps: flagged.filter { $0.daysSinceUpdate > 365 }.count,
            potentialSpaceSaved: flagged.reduce(0) { $0 + $1.sizeInMB },
            categoryCounts: Dictionary(grouping: flagged, by: \.category).mapValues(\.count)
        )
    }

    /// Discovers installed apps on the device
    /// Note: On a real device, this would use private APIs or MDM profiles.
    /// For the demo, we use realistic simulated data.
    private func discoverInstalledApps() async -> [AppInfo] {
        // Simulate discovery time
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return Self.generateRealisticAppData()
    }

    // MARK: - Simulated Data

    /// Generates realistic app data for demonstration
    static func generateRealisticAppData() -> [AppInfo] {
        let calendar = Calendar.current
        let now = Date()

        func dateAgo(days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        return [
            // --- Productivity ---
            AppInfo(id: UUID(), name: "Microsoft Word", bundleIdentifier: "com.microsoft.word",
                    category: .productivity, appStoreRating: 4.7, totalReviews: 2_800_000,
                    lastUpdated: dateAgo(days: 14), sizeInMB: 420,
                    developerName: "Microsoft Corporation", securityRisk: .safe, flagReasons: [],
                    iconName: "doc.text.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Files"]),

            AppInfo(id: UUID(), name: "QuickNote Pro", bundleIdentifier: "com.quicknote.pro",
                    category: .productivity, appStoreRating: 2.1, totalReviews: 340,
                    lastUpdated: dateAgo(days: 890), sizeInMB: 85,
                    developerName: "QuickNote Labs", securityRisk: .high,
                    flagReasons: [.poorRating, .noRecentUpdates, .abandonedByDeveloper, .securityConcerns],
                    iconName: "note.text", isSystemApp: false, popularityScore: 8,
                    hasInAppPurchases: false, privacyPermissions: ["Contacts", "Camera", "Microphone", "Location"]),

            AppInfo(id: UUID(), name: "TaskMaster", bundleIdentifier: "com.taskmaster.app",
                    category: .productivity, appStoreRating: 2.8, totalReviews: 1200,
                    lastUpdated: dateAgo(days: 540), sizeInMB: 120,
                    developerName: "TaskMaster Inc", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .duplicateApp],
                    iconName: "checklist", isSystemApp: false, popularityScore: 22,
                    hasInAppPurchases: true, privacyPermissions: ["Notifications", "Calendar"]),

            AppInfo(id: UUID(), name: "Notion", bundleIdentifier: "com.notion.app",
                    category: .productivity, appStoreRating: 4.8, totalReviews: 1_500_000,
                    lastUpdated: dateAgo(days: 7), sizeInMB: 180,
                    developerName: "Notion Labs", securityRisk: .safe, flagReasons: [],
                    iconName: "square.grid.2x2.fill", isSystemApp: false, popularityScore: 92,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"]),

            // --- Games ---
            AppInfo(id: UUID(), name: "Candy Pop Saga", bundleIdentifier: "com.candypop.saga",
                    category: .games, appStoreRating: 1.9, totalReviews: 8500,
                    lastUpdated: dateAgo(days: 720), sizeInMB: 650,
                    developerName: "PopGame Studios", securityRisk: .high,
                    flagReasons: [.poorRating, .highStorageUsage, .excessivePermissions, .negativeReviews],
                    iconName: "circle.hexagongrid.fill", isSystemApp: false, popularityScore: 15,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Contacts", "Location", "Camera", "Microphone", "Photos", "Tracking"]),

            AppInfo(id: UUID(), name: "Puzzle Quest Deluxe", bundleIdentifier: "com.puzzlequest.deluxe",
                    category: .games, appStoreRating: 2.3, totalReviews: 2100,
                    lastUpdated: dateAgo(days: 450), sizeInMB: 380,
                    developerName: "Indie Games Co", securityRisk: .medium,
                    flagReasons: [.poorRating, .highStorageUsage, .noRecentUpdates],
                    iconName: "puzzlepiece.fill", isSystemApp: false, popularityScore: 18,
                    hasInAppPurchases: true, privacyPermissions: ["Tracking", "Location"]),

            AppInfo(id: UUID(), name: "Subway Surfers", bundleIdentifier: "com.kiloo.subwaysurfers",
                    category: .games, appStoreRating: 4.5, totalReviews: 5_000_000,
                    lastUpdated: dateAgo(days: 10), sizeInMB: 310,
                    developerName: "SYBO Games", securityRisk: .safe, flagReasons: [],
                    iconName: "figure.run", isSystemApp: false, popularityScore: 97,
                    hasInAppPurchases: true, privacyPermissions: ["Tracking"]),

            AppInfo(id: UUID(), name: "Snake Classic 2019", bundleIdentifier: "com.snake.classic2019",
                    category: .games, appStoreRating: 1.5, totalReviews: 150,
                    lastUpdated: dateAgo(days: 1800), sizeInMB: 45,
                    developerName: "Unknown Dev", securityRisk: .critical,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .knownVulnerabilities, .lowPopularity],
                    iconName: "line.diagonal", isSystemApp: false, popularityScore: 2,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Contacts", "Camera"]),

            // --- Social Media ---
            AppInfo(id: UUID(), name: "Instagram", bundleIdentifier: "com.instagram.app",
                    category: .socialMedia, appStoreRating: 4.6, totalReviews: 30_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 280,
                    developerName: "Meta Platforms", securityRisk: .safe, flagReasons: [],
                    iconName: "camera.fill", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Microphone", "Location"]),

            AppInfo(id: UUID(), name: "FriendZone Chat", bundleIdentifier: "com.friendzone.chat",
                    category: .socialMedia, appStoreRating: 1.8, totalReviews: 890,
                    lastUpdated: dateAgo(days: 600), sizeInMB: 95,
                    developerName: "FZ Networks", securityRisk: .critical,
                    flagReasons: [.poorRating, .securityConcerns, .knownVulnerabilities, .excessivePermissions, .negativeReviews],
                    iconName: "person.crop.circle.badge.exclamationmark", isSystemApp: false, popularityScore: 5,
                    hasInAppPurchases: false,
                    privacyPermissions: ["Contacts", "Location", "Camera", "Microphone", "Photos", "Calendar", "Tracking"]),

            AppInfo(id: UUID(), name: "ShareIt Social", bundleIdentifier: "com.shareit.social",
                    category: .socialMedia, appStoreRating: 2.5, totalReviews: 3400,
                    lastUpdated: dateAgo(days: 380), sizeInMB: 110,
                    developerName: "ShareIt Corp", securityRisk: .high,
                    flagReasons: [.poorRating, .securityConcerns, .noRecentUpdates, .duplicateApp],
                    iconName: "arrowshape.turn.up.right.fill", isSystemApp: false, popularityScore: 12,
                    hasInAppPurchases: true, privacyPermissions: ["Contacts", "Location", "Tracking"]),

            // --- Banking & Finance ---
            AppInfo(id: UUID(), name: "Chase Mobile", bundleIdentifier: "com.chase.mobile",
                    category: .banking, appStoreRating: 4.8, totalReviews: 8_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 290,
                    developerName: "JPMorgan Chase", securityRisk: .safe, flagReasons: [],
                    iconName: "building.columns.fill", isSystemApp: false, popularityScore: 96,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Face ID", "Location"]),

            AppInfo(id: UUID(), name: "QuickLoan Express", bundleIdentifier: "com.quickloan.express",
                    category: .banking, appStoreRating: 1.4, totalReviews: 2300,
                    lastUpdated: dateAgo(days: 400), sizeInMB: 55,
                    developerName: "QLoan Finance Ltd", securityRisk: .critical,
                    flagReasons: [.poorRating, .securityConcerns, .knownVulnerabilities, .negativeReviews, .excessivePermissions],
                    iconName: "dollarsign.circle.fill", isSystemApp: false, popularityScore: 6,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Contacts", "Location", "Camera", "Photos", "Calendar", "Tracking"]),

            AppInfo(id: UUID(), name: "CryptoTracker Mini", bundleIdentifier: "com.cryptotracker.mini",
                    category: .banking, appStoreRating: 2.6, totalReviews: 560,
                    lastUpdated: dateAgo(days: 500), sizeInMB: 70,
                    developerName: "CryptoApps LLC", securityRisk: .high,
                    flagReasons: [.poorRating, .noRecentUpdates, .securityConcerns, .lowPopularity],
                    iconName: "bitcoinsign.circle.fill", isSystemApp: false, popularityScore: 10,
                    hasInAppPurchases: true, privacyPermissions: ["Tracking", "Location"]),

            // --- Travel ---
            AppInfo(id: UUID(), name: "Airbnb", bundleIdentifier: "com.airbnb.app",
                    category: .travel, appStoreRating: 4.7, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 8), sizeInMB: 320,
                    developerName: "Airbnb Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "house.fill", isSystemApp: false, popularityScore: 94,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera", "Photos"]),

            AppInfo(id: UUID(), name: "TravelBuddy Cheap", bundleIdentifier: "com.travelbuddy.cheap",
                    category: .travel, appStoreRating: 2.0, totalReviews: 780,
                    lastUpdated: dateAgo(days: 670), sizeInMB: 140,
                    developerName: "TB Ventures", securityRisk: .high,
                    flagReasons: [.poorRating, .noRecentUpdates, .negativeReviews, .excessivePermissions],
                    iconName: "globe.americas.fill", isSystemApp: false, popularityScore: 9,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Location", "Contacts", "Camera", "Microphone", "Tracking"]),

            // --- News ---
            AppInfo(id: UUID(), name: "Apple News", bundleIdentifier: "com.apple.news",
                    category: .news, appStoreRating: 4.6, totalReviews: 1_200_000,
                    lastUpdated: dateAgo(days: 2), sizeInMB: 0,
                    developerName: "Apple Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "newspaper.fill", isSystemApp: true, popularityScore: 90,
                    hasInAppPurchases: true, privacyPermissions: ["Location"]),

            AppInfo(id: UUID(), name: "NewsBlast Daily", bundleIdentifier: "com.newsblast.daily",
                    category: .news, appStoreRating: 1.7, totalReviews: 450,
                    lastUpdated: dateAgo(days: 950), sizeInMB: 60,
                    developerName: "NewsBlast Media", securityRisk: .high,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .lowPopularity, .securityConcerns],
                    iconName: "exclamationmark.bubble.fill", isSystemApp: false, popularityScore: 3,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Contacts", "Tracking"]),

            // --- Entertainment ---
            AppInfo(id: UUID(), name: "Netflix", bundleIdentifier: "com.netflix.app",
                    category: .entertainment, appStoreRating: 4.5, totalReviews: 12_000_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 130,
                    developerName: "Netflix Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "play.tv.fill", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Microphone"]),

            AppInfo(id: UUID(), name: "StreamFlix Free", bundleIdentifier: "com.streamflix.free",
                    category: .entertainment, appStoreRating: 1.6, totalReviews: 5600,
                    lastUpdated: dateAgo(days: 550), sizeInMB: 200,
                    developerName: "StreamFlix Ltd", securityRisk: .critical,
                    flagReasons: [.poorRating, .securityConcerns, .knownVulnerabilities, .negativeReviews, .duplicateApp],
                    iconName: "play.slash.fill", isSystemApp: false, popularityScore: 7,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Camera", "Microphone", "Location", "Contacts", "Photos", "Tracking"]),

            // --- Shopping ---
            AppInfo(id: UUID(), name: "Amazon", bundleIdentifier: "com.amazon.shopping",
                    category: .shopping, appStoreRating: 4.7, totalReviews: 7_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 350,
                    developerName: "AMZN Mobile LLC", securityRisk: .safe, flagReasons: [],
                    iconName: "shippingbox.fill", isSystemApp: false, popularityScore: 98,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Photos", "Location"]),

            AppInfo(id: UUID(), name: "DealHunter Pro", bundleIdentifier: "com.dealhunter.pro",
                    category: .shopping, appStoreRating: 2.2, totalReviews: 1100,
                    lastUpdated: dateAgo(days: 480), sizeInMB: 90,
                    developerName: "DealHunter Apps", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .duplicateApp, .negativeReviews],
                    iconName: "tag.slash.fill", isSystemApp: false, popularityScore: 14,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Tracking"]),

            // --- Health & Fitness ---
            AppInfo(id: UUID(), name: "MyFitnessPal", bundleIdentifier: "com.myfitnesspal",
                    category: .healthFitness, appStoreRating: 4.6, totalReviews: 3_000_000,
                    lastUpdated: dateAgo(days: 12), sizeInMB: 210,
                    developerName: "MyFitnessPal Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "heart.text.square.fill", isSystemApp: false, popularityScore: 91,
                    hasInAppPurchases: true, privacyPermissions: ["HealthKit", "Camera"]),

            AppInfo(id: UUID(), name: "FitTrack Lite", bundleIdentifier: "com.fittrack.lite",
                    category: .healthFitness, appStoreRating: 2.4, totalReviews: 670,
                    lastUpdated: dateAgo(days: 600), sizeInMB: 75,
                    developerName: "FitTrack Dev", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .duplicateApp, .lowPopularity],
                    iconName: "figure.walk", isSystemApp: false, popularityScore: 11,
                    hasInAppPurchases: false, privacyPermissions: ["HealthKit", "Location", "Camera"]),

            // --- Education ---
            AppInfo(id: UUID(), name: "Duolingo", bundleIdentifier: "com.duolingo",
                    category: .education, appStoreRating: 4.7, totalReviews: 6_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 190,
                    developerName: "Duolingo Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "character.book.closed.fill", isSystemApp: false, popularityScore: 96,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone", "Notifications"]),

            AppInfo(id: UUID(), name: "LearnCode Basic", bundleIdentifier: "com.learncode.basic",
                    category: .education, appStoreRating: 2.0, totalReviews: 320,
                    lastUpdated: dateAgo(days: 1100), sizeInMB: 55,
                    developerName: "CodeLearn Studio", securityRisk: .high,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .lowPopularity, .noRecentUpdates],
                    iconName: "chevron.left.forwardslash.chevron.right", isSystemApp: false, popularityScore: 4,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone"]),

            // --- Food & Drink ---
            AppInfo(id: UUID(), name: "DoorDash", bundleIdentifier: "com.doordash",
                    category: .foodDrink, appStoreRating: 4.7, totalReviews: 5_500_000,
                    lastUpdated: dateAgo(days: 6), sizeInMB: 250,
                    developerName: "DoorDash Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "takeoutbag.and.cup.and.straw.fill", isSystemApp: false, popularityScore: 95,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Camera"]),

            AppInfo(id: UUID(), name: "FoodSnap Free", bundleIdentifier: "com.foodsnap.free",
                    category: .foodDrink, appStoreRating: 1.9, totalReviews: 410,
                    lastUpdated: dateAgo(days: 750), sizeInMB: 85,
                    developerName: "FoodSnap Inc", securityRisk: .high,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .duplicateApp, .negativeReviews],
                    iconName: "fork.knife.circle", isSystemApp: false, popularityScore: 6,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Camera", "Contacts"]),

            // --- Utilities ---
            AppInfo(id: UUID(), name: "Flashlight Ultra", bundleIdentifier: "com.flashlight.ultra",
                    category: .utilities, appStoreRating: 1.3, totalReviews: 9800,
                    lastUpdated: dateAgo(days: 1500), sizeInMB: 35,
                    developerName: "Light Apps LLC", securityRisk: .critical,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .knownVulnerabilities, .excessivePermissions, .duplicateApp],
                    iconName: "flashlight.off.fill", isSystemApp: false, popularityScore: 3,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Camera", "Location", "Contacts", "Photos", "Tracking"]),

            AppInfo(id: UUID(), name: "Battery Doctor Plus", bundleIdentifier: "com.batterydoctor.plus",
                    category: .utilities, appStoreRating: 1.8, totalReviews: 4500,
                    lastUpdated: dateAgo(days: 900), sizeInMB: 48,
                    developerName: "Battery Apps", securityRisk: .high,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .negativeReviews, .excessivePermissions],
                    iconName: "battery.25", isSystemApp: false, popularityScore: 5,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Contacts", "Tracking"]),

            // --- Photography ---
            AppInfo(id: UUID(), name: "VSCO", bundleIdentifier: "com.vsco",
                    category: .photography, appStoreRating: 4.5, totalReviews: 2_500_000,
                    lastUpdated: dateAgo(days: 9), sizeInMB: 160,
                    developerName: "Visual Supply Company", securityRisk: .safe, flagReasons: [],
                    iconName: "camera.filters", isSystemApp: false, popularityScore: 88,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos"]),

            AppInfo(id: UUID(), name: "PhotoFilter 360", bundleIdentifier: "com.photofilter360",
                    category: .photography, appStoreRating: 2.1, totalReviews: 890,
                    lastUpdated: dateAgo(days: 580), sizeInMB: 130,
                    developerName: "Filter Apps Co", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .duplicateApp],
                    iconName: "camera.badge.ellipsis", isSystemApp: false, popularityScore: 13,
                    hasInAppPurchases: true, privacyPermissions: ["Camera", "Photos", "Location"]),

            // --- Weather ---
            AppInfo(id: UUID(), name: "WeatherBug Classic", bundleIdentifier: "com.weatherbug.classic",
                    category: .weather, appStoreRating: 2.3, totalReviews: 3400,
                    lastUpdated: dateAgo(days: 650), sizeInMB: 95,
                    developerName: "WeatherBug Legacy", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .duplicateApp, .negativeReviews],
                    iconName: "cloud.bolt.fill", isSystemApp: false, popularityScore: 16,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Tracking"]),

            // --- Communication ---
            AppInfo(id: UUID(), name: "WhatsApp", bundleIdentifier: "com.whatsapp",
                    category: .communication, appStoreRating: 4.7, totalReviews: 20_000_000,
                    lastUpdated: dateAgo(days: 4), sizeInMB: 210,
                    developerName: "Meta Platforms", securityRisk: .safe, flagReasons: [],
                    iconName: "phone.bubble.fill", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: false, privacyPermissions: ["Camera", "Microphone", "Contacts", "Photos"]),

            AppInfo(id: UUID(), name: "ChatNow Free", bundleIdentifier: "com.chatnow.free",
                    category: .communication, appStoreRating: 1.6, totalReviews: 1200,
                    lastUpdated: dateAgo(days: 800), sizeInMB: 65,
                    developerName: "ChatNow Dev", securityRisk: .critical,
                    flagReasons: [.poorRating, .securityConcerns, .knownVulnerabilities, .abandonedByDeveloper, .duplicateApp],
                    iconName: "bubble.left.and.exclamationmark.bubble.right.fill", isSystemApp: false, popularityScore: 4,
                    hasInAppPurchases: false,
                    privacyPermissions: ["Contacts", "Camera", "Microphone", "Location", "Photos", "Tracking"]),

            // --- Music ---
            AppInfo(id: UUID(), name: "Spotify", bundleIdentifier: "com.spotify",
                    category: .music, appStoreRating: 4.8, totalReviews: 15_000_000,
                    lastUpdated: dateAgo(days: 3), sizeInMB: 180,
                    developerName: "Spotify AB", securityRisk: .safe, flagReasons: [],
                    iconName: "music.note.list", isSystemApp: false, popularityScore: 99,
                    hasInAppPurchases: true, privacyPermissions: ["Microphone"]),

            AppInfo(id: UUID(), name: "MP3 Downloader Free", bundleIdentifier: "com.mp3dl.free",
                    category: .music, appStoreRating: 1.4, totalReviews: 6700,
                    lastUpdated: dateAgo(days: 1200), sizeInMB: 42,
                    developerName: "Unknown Developer", securityRisk: .critical,
                    flagReasons: [.poorRating, .securityConcerns, .knownVulnerabilities, .abandonedByDeveloper, .excessivePermissions],
                    iconName: "music.note.tv.fill", isSystemApp: false, popularityScore: 2,
                    hasInAppPurchases: true,
                    privacyPermissions: ["Contacts", "Location", "Camera", "Photos", "Files", "Tracking"]),

            // --- Navigation ---
            AppInfo(id: UUID(), name: "GPS Tracker Old", bundleIdentifier: "com.gpstracker.old",
                    category: .navigation, appStoreRating: 2.0, totalReviews: 560,
                    lastUpdated: dateAgo(days: 1050), sizeInMB: 78,
                    developerName: "GPS Legacy Apps", securityRisk: .high,
                    flagReasons: [.poorRating, .abandonedByDeveloper, .noRecentUpdates, .lowPopularity, .duplicateApp],
                    iconName: "location.slash.fill", isSystemApp: false, popularityScore: 5,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Contacts", "Tracking"]),

            // --- Lifestyle ---
            AppInfo(id: UUID(), name: "Horoscope Daily Pro", bundleIdentifier: "com.horoscope.dailypro",
                    category: .lifestyle, appStoreRating: 2.2, totalReviews: 1800,
                    lastUpdated: dateAgo(days: 420), sizeInMB: 60,
                    developerName: "StarSign Apps", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .negativeReviews],
                    iconName: "moon.stars.fill", isSystemApp: false, popularityScore: 15,
                    hasInAppPurchases: true, privacyPermissions: ["Location", "Contacts", "Tracking"]),

            // --- Sports ---
            AppInfo(id: UUID(), name: "ESPN", bundleIdentifier: "com.espn",
                    category: .sports, appStoreRating: 4.6, totalReviews: 4_000_000,
                    lastUpdated: dateAgo(days: 5), sizeInMB: 250,
                    developerName: "ESPN Inc.", securityRisk: .safe, flagReasons: [],
                    iconName: "sportscourt.fill", isSystemApp: false, popularityScore: 93,
                    hasInAppPurchases: true, privacyPermissions: ["Location"]),

            AppInfo(id: UUID(), name: "ScoreBoard Lite", bundleIdentifier: "com.scoreboard.lite",
                    category: .sports, appStoreRating: 2.1, totalReviews: 340,
                    lastUpdated: dateAgo(days: 700), sizeInMB: 45,
                    developerName: "SB Apps LLC", securityRisk: .medium,
                    flagReasons: [.poorRating, .noRecentUpdates, .lowPopularity, .duplicateApp],
                    iconName: "number.circle.fill", isSystemApp: false, popularityScore: 7,
                    hasInAppPurchases: false, privacyPermissions: ["Location", "Tracking"]),
        ]
    }
}
