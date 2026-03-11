import SwiftUI

struct ResultsView: View {
    @ObservedObject var viewModel: AppAnalyzerViewModel
    @State private var showSortOptions = false
    @State private var viewMode: ViewMode = .category
    @State private var animateCards = false

    enum ViewMode: String, CaseIterable {
        case category = "Category"
        case list = "List"
        case risk = "Risk Level"
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

                // Search Bar
                searchBar

                // Content
                ScrollView {
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
                SummaryChip(value: "\(summary.totalApps)", label: "Total Apps", icon: "app.fill", color: .blue)
                SummaryChip(value: "\(summary.flaggedApps)", label: "Flagged", icon: "exclamationmark.triangle.fill", color: .orange)
                SummaryChip(value: "\(summary.securityRisks)", label: "Security Risks", icon: "shield.slash.fill", color: .red)
                SummaryChip(value: "\(summary.outdatedApps)", label: "Outdated", icon: "clock.badge.exclamationmark", color: .yellow)
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
            // View Mode Picker
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Sort Button
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

    // MARK: - Category View

    private var categoryView: some View {
        ForEach(viewModel.groupedFlaggedApps, id: \.0) { category, apps in
            CategorySection(
                category: category,
                apps: apps,
                selectedApps: viewModel.selectedAppsForDeletion,
                onToggle: { viewModel.toggleAppSelection($0) },
                onSelectAll: { viewModel.selectAllInCategory(category) },
                onDeselectAll: { viewModel.deselectAllInCategory(category) },
                onDetail: { viewModel.showAppDetail = $0 }
            )
        }
    }

    // MARK: - List View

    private var listView: some View {
        ForEach(viewModel.filteredFlaggedApps) { app in
            AppRow(
                app: app,
                isSelected: viewModel.selectedAppsForDeletion.contains(app.id),
                onToggle: { viewModel.toggleAppSelection(app) },
                onDetail: { viewModel.showAppDetail = app }
            )
        }
    }

    // MARK: - Risk View

    private var riskView: some View {
        let grouped = Dictionary(grouping: viewModel.filteredFlaggedApps, by: \.securityRisk)
        let sorted = grouped.sorted { $0.key > $1.key }

        return ForEach(sorted, id: \.key) { risk, apps in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: risk.icon)
                        .foregroundStyle(risk.color)
                    Text(risk.rawValue)
                        .font(.headline)
                    Spacer()
                    Text("\(apps.count) apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                ForEach(apps) { app in
                    AppRow(
                        app: app,
                        isSelected: viewModel.selectedAppsForDeletion.contains(app.id),
                        onToggle: { viewModel.toggleAppSelection(app) },
                        onDetail: { viewModel.showAppDetail = app }
                    )
                }
            }
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
            // Category Header
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.title3)

                Text(category.rawValue)
                    .font(.headline)

                Spacer()

                Text("\(apps.count) flagged")
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

            // App Cards
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

// MARK: - App Row

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
