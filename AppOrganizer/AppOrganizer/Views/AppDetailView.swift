import SwiftUI

struct AppDetailView: View {
    let app: AppInfo
    @ObservedObject var viewModel: AppOrganizerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // App Header
                    appHeader

                    // Risk Badge
                    riskBadge

                    // Quick Stats
                    quickStats

                    // Flag Reasons
                    flagReasonsSection

                    // Permissions
                    permissionsSection

                    // App Details
                    detailsSection

                    // Recommendation
                    recommendationSection

                    // Action Buttons
                    actionButtons
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("App Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete \(app.name)?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteSingleApp(app)
                    dismiss()
                }
            } message: {
                Text("This will mark \(app.name) for removal and free up \(app.formattedSize). To fully delete it, go to Settings > General > iPhone Storage.")
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [app.securityRisk.color.opacity(0.15), app.securityRisk.color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: app.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(app.securityRisk.color)
            }

            Text(app.name)
                .font(.title2.bold())

            Text(app.developerName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(app.category.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(app.category.color.opacity(0.1))
                .foregroundStyle(app.category.color)
                .clipShape(Capsule())
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -10)
    }

    // MARK: - Risk Badge

    private var riskBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: app.securityRisk.icon)
                .font(.title)
                .foregroundStyle(app.securityRisk.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Security Assessment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(app.securityRisk.rawValue)
                    .font(.title3.bold())
                    .foregroundStyle(app.securityRisk.color)
            }

            Spacer()
        }
        .padding(16)
        .background(app.securityRisk.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 0) {
            DetailStat(title: "Rating", value: String(format: "%.1f", app.appStoreRating),
                      icon: "star.fill", color: app.appStoreRating >= 4.0 ? .green : (app.appStoreRating >= 3.0 ? .yellow : .red))

            Divider().frame(height: 40)

            DetailStat(title: "Reviews", value: formatNumber(app.totalReviews),
                      icon: "text.bubble.fill", color: .blue)

            Divider().frame(height: 40)

            DetailStat(title: "Size", value: app.formattedSize,
                      icon: "externaldrive.fill", color: .purple)

            Divider().frame(height: 40)

            DetailStat(title: "Popularity", value: "\(app.popularityScore)/100",
                      icon: "chart.bar.fill", color: app.popularityScore >= 50 ? .green : .orange)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Flag Reasons

    private var flagReasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Issues Found (\(app.flagReasons.count))")
                    .font(.headline)
            }

            ForEach(app.flagReasons) { reason in
                HStack(spacing: 12) {
                    Image(systemName: reason.icon)
                        .font(.body)
                        .foregroundStyle(reason.color)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reason.rawValue)
                            .font(.subheadline.bold())
                        Text(descriptionFor(reason))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(reason.color.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.blue)
                Text("Permissions (\(app.privacyPermissions.count))")
                    .font(.headline)
                Spacer()
                if app.privacyPermissions.count > 4 {
                    Text("Excessive")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(app.privacyPermissions, id: \.self) { permission in
                    PermissionChip(permission: permission, isExcessive: isExcessivePermission(permission))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("App Details")
                    .font(.headline)
            }

            VStack(spacing: 0) {
                DetailRow(label: "Bundle ID", value: app.bundleIdentifier)
                Divider()
                DetailRow(label: "Developer", value: app.developerName)
                Divider()
                DetailRow(label: "Last Updated", value: formattedDate(app.lastUpdated))
                Divider()
                DetailRow(label: "Days Since Update", value: "\(app.daysSinceUpdate) days")
                Divider()
                DetailRow(label: "In-App Purchases", value: app.hasInAppPurchases ? "Yes" : "No")
                Divider()
                DetailRow(label: "System App", value: app.isSystemApp ? "Yes" : "No")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: app.securityRisk >= .high ? "exclamationmark.octagon.fill" : "lightbulb.fill")
                    .foregroundStyle(app.securityRisk >= .high ? .red : .yellow)
                Text("Recommendation")
                    .font(.headline)
            }

            Text(recommendationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            (app.securityRisk >= .high ? Color.red : Color.yellow).opacity(0.05)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete This App")
                        .bold()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                viewModel.openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open iPhone Settings")
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Helpers

    private var recommendationText: String {
        switch app.securityRisk {
        case .critical:
            return "We strongly recommend deleting this app immediately. It has known security vulnerabilities and may put your personal data at risk. The app hasn't been updated in \(app.daysSinceUpdate) days."
        case .high:
            return "This app poses significant security concerns. Consider deleting it and finding a safer alternative with better ratings and regular updates."
        case .medium:
            return "This app has some issues that may concern you. It could be replaced with a more popular and better-maintained alternative."
        case .low:
            return "This app has minor issues. It's not a major concern, but you might find better alternatives available."
        case .safe:
            return "This app appears to be safe and well-maintained. No action needed."
        }
    }

    private func descriptionFor(_ reason: FlagReason) -> String {
        switch reason {
        case .poorRating:
            return "Rated \(String(format: "%.1f", app.appStoreRating))/5.0 stars on the App Store"
        case .noRecentUpdates:
            return "Last updated \(app.daysSinceUpdate) days ago"
        case .securityConcerns:
            return "Users have reported security issues with this app"
        case .lowPopularity:
            return "Popularity score: \(app.popularityScore)/100"
        case .duplicateApp:
            return "Similar functionality available in better-rated apps"
        case .highStorageUsage:
            return "Using \(app.formattedSize) of storage space"
        case .excessivePermissions:
            return "Requests \(app.privacyPermissions.count) permissions, more than typical for its category"
        case .negativeReviews:
            return "Many users report poor experience in reviews"
        case .abandonedByDeveloper:
            return "Developer appears to have stopped maintaining this app"
        case .knownVulnerabilities:
            return "Security researchers have identified vulnerabilities"
        }
    }

    private func isExcessivePermission(_ permission: String) -> Bool {
        let sensitivePermissions = ["Contacts", "Location", "Microphone", "Tracking", "Calendar"]
        return sensitivePermissions.contains(permission)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Detail Stat

struct DetailStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Permission Chip

struct PermissionChip: View {
    let permission: String
    let isExcessive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconFor(permission))
                .font(.caption2)
            Text(permission)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isExcessive ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground))
        .foregroundStyle(isExcessive ? .red : .primary)
        .clipShape(Capsule())
    }

    private func iconFor(_ permission: String) -> String {
        switch permission {
        case "Camera": return "camera.fill"
        case "Photos": return "photo.fill"
        case "Location": return "location.fill"
        case "Contacts": return "person.crop.circle.fill"
        case "Microphone": return "mic.fill"
        case "Calendar": return "calendar"
        case "Tracking": return "eye.fill"
        case "HealthKit": return "heart.fill"
        case "Files": return "folder.fill"
        case "Face ID": return "faceid"
        case "Notifications": return "bell.fill"
        default: return "app.fill"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}
