import SwiftUI

struct ResultsView: View {
    @ObservedObject var viewModel: AppAnalyzerViewModel
    @State private var showSortOptions = false
    @State private var viewMode: ViewMode = .category
    @State private var animateCards = false
    @State private var showFlaggedOnly = false

    enum ViewMode: String, CaseIterable {
        case category = "Category"
        case list = "List"
        case risk = "Risk Level"
    }

    var displayedApps: [AppInfo] {
        showFlaggedOnly ? viewModel.filteredFlaggedApps : viewModel.filteredInstalledApps
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Banner
                if let summary = viewModel.analyzerService.scanSummary {
                    summaryBanner(summary)
                }

                // Controls Bar
                controlsBar

                // Filter Toggle
                filterToggle

                // Search Bar
                searchBar

                // Content
                ScrollView {
                    if displayedApps.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 16) {
                            switch viewMode {
                            case .category:
                                categoryView
                            case .list:
                                listView
                            case .risk:
                                riskView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, viewModel.selectedAppsForDeletion.isEmpty ? 20 : 100)
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home") {
                        viewModel.resetAndGoHome()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startScan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !viewModel.selectedAppsForDeletion.isEmpty {
                    deleteBar
                }
            }
            .sheet(item: $viewModel.showAppDetail) { app in
                AppDetailView(app: app, viewModel: viewModel)
            }
            .alert("Delete \(viewModel.selectedAppsForDeletion.count) App(s)?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteSelectedApps()
                }
            } message: {
                Text("This will remove the selected apps. You'll free up \(viewModel.formattedSelectedSize) of storage space.")
            }
            .alert("Successfully Removed!", isPresented: $viewModel.showDeleteSuccess) {
                Button("OK") {}
            } message: {
                Text("\(viewModel.deletedCount) app(s) have been removed from the list. To fully delete them from your device, go to Settings > General > iPhone Storage.")
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateCards = true
            }
        }
    }

    // MARK: - Summary Banner

    private func summaryBanner(_ summary: ScanSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SummaryChip(value: "\(summary.totalApps)", label: "Installed", icon: "app.fill", color: .blue)
                SummaryChip(value: "\(summary.flaggedApps)", label: "Flagged", icon: "exclamationmark.triangle.fill", color: .orange)
                SummaryChip(value: "\(summary.securityRisks)", label: "Security Risks", icon: "shield.slash.fill", color: .red)
                SummaryChip(value: "\(summary.outdatedApps)", label: "Outdated", icon: "clock.badge.exclamationmark", color: .yellow)
                SummaryChip(value: "\(summary.unusedApps)", label: "Unused", icon: "hourglass.bottomhalf.filled", color: .indigo)
                SummaryChip(value: "\(summary.suggestedDeletions)", label: "Delete", icon: "trash.circle.fill", color: .red)
                SummaryChip(value: "\(summary.totalApps - summary.flaggedApps)", label: "Clean", icon: "checkmark.shield.fill", color: .green)
                SummaryChip(value: summary.formattedSpaceSaved, label: "Can Free Up", icon: "externaldrive.fill", color: .purple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Toggle

    private var filterToggle: some View {
        HStack(spacing: 10) {
            FilterChip(
                title: "All Apps",
                count: viewModel.filteredInstalledApps.count,
                isActive: !showFlaggedOnly,
                color: .blue
            ) {
                withAnimation(.easeInOut(duration: 0.25)) { showFlaggedOnly = false }
            }

            FilterChip(
                title: "Flagged Only",
                count: viewModel.filteredFlaggedApps.count,
                isActive: showFlaggedOnly,
                color: .orange
            ) {
                withAnimation(.easeInOut(duration: 0.25)) { showFlaggedOnly = true }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: showFlaggedOnly ? "checkmark.shield.fill" : "app.dashed")
                .font(.system(size: 48))
                .foregroundStyle(showFlaggedOnly ? .green : .secondary)

            Text(showFlaggedOnly ? "No Flagged Apps!" : "No Apps Found")
                .font(.title3.bold())

            Text(showFlaggedOnly
                 ? "All your installed apps look clean and safe."
                 : "No installed apps matched your selected categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if showFlaggedOnly {
                Button("Show All Apps") {
                    withAnimation { showFlaggedOnly = false }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category View

    private var categoryView: some View {
        let grouped: [(AppCategory, [AppInfo])]
        if showFlaggedOnly {
            grouped = viewModel.groupedFlaggedApps
        } else {
            grouped = viewModel.groupedAllApps
        }

        return ForEach(grouped, id: \.0) { category, apps in
            let flaggedInCategory = apps.filter { $0.isFlagged }
            let safeInCategory = apps.filter { !$0.isFlagged }

            VStack(alignment: .leading, spacing: 0) {
                // Category Header
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                        .font(.title3)

                    Text(category.rawValue)
                        .font(.headline)

                    Spacer()

                    if !flaggedInCategory.isEmpty {
                        Text("\(flaggedInCategory.count) flagged")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    Text("\(apps.count) apps")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.color.opacity(0.1))
                        .foregroundStyle(category.color)
                        .clipShape(Capsule())

                    Button(apps.allSatisfy({ viewModel.selectedAppsForDeletion.contains($0.id) }) ? "Deselect All" : "Select All") {
                        if apps.allSatisfy({ viewModel.selectedAppsForDeletion.contains($0.id) }) {
                            viewModel.deselectAllInCategory(category)
                        } else {
                            viewModel.selectAllInCategory(category)
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
                .padding(.bottom, 8)

                // Flagged apps first
                if !flaggedInCategory.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(flaggedInCategory) { app in
                            AppRow(
                                app: app,
                                isSelected: viewModel.selectedAppsForDeletion.contains(app.id),
                                onToggle: { viewModel.toggleAppSelection(app) },
                                onDetail: { viewModel.showAppDetail = app }
                            )
                        }
                    }
                }

                // Safe apps below with a divider
                if !safeInCategory.isEmpty && !showFlaggedOnly {
                    if !flaggedInCategory.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                            Text("Clean")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                        }
                        .padding(.vertical, 8)
                    }

                    VStack(spacing: 6) {
                        ForEach(safeInCategory) { app in
                            SafeAppRow(
                                app: app,
                                onDetail: { viewModel.showAppDetail = app }
                            )
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - List View

    private var listView: some View {
        let apps = displayedApps
        let flagged = apps.filter { $0.isFlagged }
        let safe = apps.filter { !$0.isFlagged }

        return VStack(spacing: 8) {
            // Flagged section
            if !flagged.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Flagged Apps")
                        .font(.headline)
                    Spacer()
                    Text("\(flagged.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 4)

                ForEach(flagged) { app in
                    AppRow(
                        app: app,
                        isSelected: viewModel.selectedAppsForDeletion.contains(app.id),
                        onToggle: { viewModel.toggleAppSelection(app) },
                        onDetail: { viewModel.showAppDetail = app }
                    )
                }
            }

            // Safe section
            if !safe.isEmpty && !showFlaggedOnly {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Clean Apps")
                        .font(.headline)
                    Spacer()
                    Text("\(safe.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 4)
                .padding(.top, flagged.isEmpty ? 0 : 12)

                ForEach(safe) { app in
                    SafeAppRow(
                        app: app,
                        onDetail: { viewModel.showAppDetail = app }
                    )
                }
            }
        }
    }

    // MARK: - Risk View

    private var riskView: some View {
        let apps = displayedApps
        let grouped = Dictionary(grouping: apps, by: \.securityRisk)
        let sorted = grouped.sorted { $0.key > $1.key }

        return ForEach(sorted, id: \.key) { risk, riskApps in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: risk.icon)
                        .foregroundStyle(risk.color)
                    Text(risk.rawValue)
                        .font(.headline)
                    Spacer()
                    Text("\(riskApps.count) apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                ForEach(riskApps) { app in
                    if app.isFlagged {
                        AppRow(
                            app: app,
                            isSelected: viewModel.selectedAppsForDeletion.contains(app.id),
                            onToggle: { viewModel.toggleAppSelection(app) },
                            onDetail: { viewModel.showAppDetail = app }
                        )
                    } else {
                        SafeAppRow(
                            app: app,
                            onDetail: { viewModel.showAppDetail = app }
                        )
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Delete Bar

    private var deleteBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.selectedAppsForDeletion.count) selected")
                    .font(.subheadline.bold())
                Text("Free up \(viewModel.formattedSelectedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.selectedAppsForDeletion.removeAll()
            } label: {
                Text("Clear")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Delete")
                        .bold()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Summary Chip

struct SummaryChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.bold())
                Text("\(count)")
                    .font(.caption2.bold().monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isActive ? Color.white.opacity(0.3) : Color(.systemGray4))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? color : Color(.systemGray6))
            .foregroundStyle(isActive ? .white : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? color : Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let category: AppCategory
    let apps: [AppInfo]
    let selectedApps: Set<UUID>
    let onToggle: (AppInfo) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onDetail: (AppInfo) -> Void

    private var allSelected: Bool {
        apps.allSatisfy { selectedApps.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.title3)

                Text(category.rawValue)
                    .font(.headline)

                Spacer()

                Text("\(apps.count) apps")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.1))
                    .foregroundStyle(category.color)
                    .clipShape(Capsule())

                Button(allSelected ? "Deselect All" : "Select All") {
                    allSelected ? onDeselectAll() : onSelectAll()
                }
                .font(.caption.bold())
                .foregroundStyle(.blue)
            }

            ForEach(apps) { app in
                AppRow(
                    app: app,
                    isSelected: selectedApps.contains(app.id),
                    onToggle: { onToggle(app) },
                    onDetail: { onDetail(app) }
                )
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - App Row (Flagged)

struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onToggle: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .red : .secondary)
            }

            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(app.securityRisk.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: app.iconName)
                    .font(.title3)
                    .foregroundStyle(app.securityRisk.color)
            }

            // App Info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: app.securityRisk.icon)
                        .font(.caption2)
                        .foregroundStyle(app.securityRisk.color)
                    Text(app.securityRisk.rawValue)
                        .font(.caption2)
                        .foregroundStyle(app.securityRisk.color)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("★ \(String(format: "%.1f", app.appStoreRating))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(app.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Flag reasons (first 2)
                if !app.flagReasons.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(app.flagReasons.prefix(2))) { reason in
                            Text(reason.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(reason.color.opacity(0.1))
                                .foregroundStyle(reason.color)
                                .clipShape(Capsule())
                        }
                        if app.flagReasons.count > 2 {
                            Text("+\(app.flagReasons.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Detail Arrow
            Button(action: onDetail) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.red.opacity(0.05) : Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Safe App Row (Clean apps - compact style)

struct SafeAppRow: View {
    let app: AppInfo
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Safe icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: app.iconName)
                    .font(.body)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Safe")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("★ \(String(format: "%.1f", app.appStoreRating))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(app.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDetail) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground).opacity(0.6))
        )
    }
}
