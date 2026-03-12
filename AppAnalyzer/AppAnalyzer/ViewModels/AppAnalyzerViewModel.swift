import Foundation
import SwiftUI
import Combine

/// Main ViewModel coordinating the entire app flow
@MainActor
final class AppAnalyzerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentScreen: AppScreen = .home
    @Published var preferences = ScanPreferences.default
    @Published var selectedAppsForDeletion: Set<UUID> = []
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false
    @Published var deletedCount = 0
    @Published var searchText = ""
    @Published var sortOption: SortOption = .riskLevel
    @Published var filterRisk: SecurityRisk?
    @Published var showAppDetail: AppInfo?
    @Published var hasCompletedOnboarding: Bool

    let analyzerService = AppAnalyzerService()

    // MARK: - Computed Properties

    /// All installed apps after filtering/sorting (flagged + safe)
    var filteredInstalledApps: [AppInfo] {
        var apps = analyzerService.installedApps

        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.developerName.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let risk = filterRisk {
            apps = apps.filter { $0.securityRisk == risk }
        }

        switch sortOption {
        case .riskLevel:
            apps.sort { $0.securityRisk > $1.securityRisk }
        case .deletionRec:
            apps.sort { $0.deletionRecommendation > $1.deletionRecommendation }
        case .appName:
            apps.sort { $0.name < $1.name }
        case .rating:
            apps.sort { $0.appStoreRating < $1.appStoreRating }
        case .size:
            apps.sort { $0.sizeInMB > $1.sizeInMB }
        case .lastUpdated:
            apps.sort { $0.lastUpdated < $1.lastUpdated }
        case .lastUsed:
            apps.sort {
                let a = $0.lastUsedDate ?? .distantPast
                let b = $1.lastUsedDate ?? .distantPast
                return a < b // Oldest first
            }
        case .popularity:
            apps.sort { $0.popularityScore < $1.popularityScore }
        }

        return apps
    }

    /// Only flagged apps after filtering/sorting
    var filteredFlaggedApps: [AppInfo] {
        filteredInstalledApps.filter { $0.isFlagged }
    }

    var groupedFlaggedApps: [(AppCategory, [AppInfo])] {
        let grouped = Dictionary(grouping: filteredFlaggedApps, by: \.category)
        return grouped.sorted { $0.value.count > $1.value.count }
    }

    /// All installed apps grouped by category
    var groupedAllApps: [(AppCategory, [AppInfo])] {
        let grouped = Dictionary(grouping: filteredInstalledApps, by: \.category)
        return grouped.sorted { $0.value.count > $1.value.count }
    }

    var totalSelectedSize: Double {
        analyzerService.installedApps
            .filter { selectedAppsForDeletion.contains($0.id) }
            .reduce(0) { $0 + $1.sizeInMB }
    }

    var formattedSelectedSize: String {
        if totalSelectedSize >= 1024 {
            return String(format: "%.1f GB", totalSelectedSize / 1024)
        }
        return String(format: "%.0f MB", totalSelectedSize)
    }

    // MARK: - Init

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Actions

    func startScan() {
        currentScreen = .scanning
        Task {
            await analyzerService.performScan(preferences: preferences)
            currentScreen = .results
        }
    }

    func toggleAppSelection(_ app: AppInfo) {
        if selectedAppsForDeletion.contains(app.id) {
            selectedAppsForDeletion.remove(app.id)
        } else {
            selectedAppsForDeletion.insert(app.id)
        }
    }

    func selectAllInCategory(_ category: AppCategory) {
        let apps = analyzerService.installedApps.filter { $0.category == category }
        for app in apps {
            selectedAppsForDeletion.insert(app.id)
        }
    }

    func deselectAllInCategory(_ category: AppCategory) {
        let apps = analyzerService.installedApps.filter { $0.category == category }
        for app in apps {
            selectedAppsForDeletion.remove(app.id)
        }
    }

    func deleteSelectedApps() {
        Task {
            let appsToDelete = analyzerService.installedApps.filter {
                selectedAppsForDeletion.contains($0.id)
            }
            let count = await analyzerService.deleteApps(appsToDelete)
            selectedAppsForDeletion.removeAll()
            deletedCount = count
            showDeleteSuccess = true
        }
    }

    func deleteSingleApp(_ app: AppInfo) {
        Task {
            _ = await analyzerService.deleteApp(app)
            selectedAppsForDeletion.remove(app.id)
            deletedCount = 1
            showDeleteSuccess = true
        }
    }

    func resetAndGoHome() {
        currentScreen = .home
        selectedAppsForDeletion.removeAll()
        searchText = ""
        filterRisk = nil
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    /// Opens iOS Settings to allow actual app deletion
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Types

enum AppScreen {
    case home
    case categorySelection
    case scanning
    case results
}

enum SortOption: String, CaseIterable {
    case riskLevel = "Risk Level"
    case deletionRec = "Deletion Rec."
    case appName = "App Name"
    case rating = "Rating"
    case size = "Size"
    case lastUpdated = "Last Updated"
    case lastUsed = "Last Used"
    case popularity = "Popularity"

    var icon: String {
        switch self {
        case .riskLevel: return "shield.fill"
        case .deletionRec: return "trash.circle.fill"
        case .appName: return "textformat"
        case .rating: return "star.fill"
        case .size: return "externaldrive.fill"
        case .lastUpdated: return "clock.fill"
        case .lastUsed: return "hourglass"
        case .popularity: return "person.3.fill"
        }
    }
}
