import SwiftUI

struct CategorySelectionView: View {
    @ObservedObject var viewModel: AppAnalyzerViewModel
    @State private var animateItems = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Quick Actions
                    quickActions

                    // Category Grid
                    categoryGrid

                    // Scan Options
                    scanOptionsSection

                    // Start Scan Button
                    startScanButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        withAnimation {
                            viewModel.currentScreen = .home
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateItems = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("What apps do you use?")
                .font(.title3.bold())

            Text("Select the categories you care about.\nWe'll find unwanted apps in these categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.preferences.selectedCategories = Set(AppCategory.allCases)
                }
            } label: {
                Label("Select All", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.preferences.selectedCategories.removeAll()
                }
            } label: {
                Label("Clear All", systemImage: "xmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(AppCategory.allCases.enumerated()), id: \.element.id) { index, category in
                CategoryCard(
                    category: category,
                    isSelected: viewModel.preferences.selectedCategories.contains(category)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        toggleCategory(category)
                    }
                }
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.03), value: animateItems)
            }
        }
    }

    // MARK: - Scan Options

    private var scanOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Options")
                .font(.headline)

            VStack(spacing: 0) {
                ScanOptionToggle(
                    icon: "shield.fill",
                    title: "Check Security Risks",
                    isOn: $viewModel.preferences.checkSecurityRisks,
                    color: .red
                )
                Divider().padding(.leading, 44)
                ScanOptionToggle(
                    icon: "clock.fill",
                    title: "Check for Outdated Apps",
                    isOn: $viewModel.preferences.checkForUpdates,
                    color: .orange
                )
                Divider().padding(.leading, 44)
                ScanOptionToggle(
                    icon: "person.3.fill",
                    title: "Check App Popularity",
                    isOn: $viewModel.preferences.checkPopularity,
                    color: .blue
                )
                Divider().padding(.leading, 44)
                ScanOptionToggle(
                    icon: "doc.on.doc.fill",
                    title: "Find Duplicate Apps",
                    isOn: $viewModel.preferences.checkDuplicates,
                    color: .purple
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Start Scan Button

    private var startScanButton: some View {
        Button {
            viewModel.startScan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.title3)
                Text("Start Scanning")
                    .font(.title3.bold())
                Text("(\(viewModel.preferences.selectedCategories.count) categories)")
                    .font(.subheadline)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.preferences.selectedCategories.isEmpty
                ? AnyShapeStyle(Color.gray)
                : AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(viewModel.preferences.selectedCategories.isEmpty)
    }

    // MARK: - Helpers

    private func toggleCategory(_ category: AppCategory) {
        if viewModel.preferences.selectedCategories.contains(category) {
            viewModel.preferences.selectedCategories.remove(category)
        } else {
            viewModel.preferences.selectedCategories.insert(category)
        }
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: AppCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color.opacity(0.3) : Color(.systemGray5))
                        .frame(width: 44, height: 44)

                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? category.color : Color(.systemGray3))
                }

                Text(category.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(isSelected ? .white : Color(.systemGray2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? category.color.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? category.color : Color(.systemGray5), lineWidth: isSelected ? 2.5 : 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scan Option Toggle

struct ScanOptionToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(.subheadline)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
