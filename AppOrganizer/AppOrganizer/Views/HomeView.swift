import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppOrganizerViewModel
    @State private var animateShield = false
    @State private var animatePulse = false
    @State private var showFeatures = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    heroSection

                    // Feature Cards
                    featureCards

                    // Scan Button
                    scanButton

                    // Quick Stats
                    quickStatsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("App Organizer")
                            .font(.title2.bold())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.openSettings()
                    } label: {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animateShield = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showFeatures = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated background circles
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: animatePulse ? 180 : 160)

                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: animatePulse ? 140 : 130)

                // Shield icon
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateShield ? 1.0 : 0.5)
                    .opacity(animateShield ? 1.0 : 0.0)
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Keep Your iPhone Clean & Secure")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Scan your apps to find unwanted, insecure, and outdated apps that waste space and put your data at risk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FeatureCard(
                    icon: "shield.slash.fill",
                    title: "Security Check",
                    description: "Find apps with known vulnerabilities",
                    color: .red
                )
                FeatureCard(
                    icon: "clock.badge.exclamationmark",
                    title: "Update Check",
                    description: "Detect abandoned apps",
                    color: .orange
                )
            }

            HStack(spacing: 12) {
                FeatureCard(
                    icon: "star.slash.fill",
                    title: "Rating Analysis",
                    description: "Spot poorly rated apps",
                    color: .yellow
                )
                FeatureCard(
                    icon: "externaldrive.fill",
                    title: "Space Saver",
                    description: "Free up valuable storage",
                    color: .purple
                )
            }
        }
        .opacity(showFeatures ? 1 : 0)
        .offset(y: showFeatures ? 0 : 20)
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            withAnimation(.spring(response: 0.4)) {
                viewModel.currentScreen = .categorySelection
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title2)
                Text("Scan My Apps")
                    .font(.title3.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why Scan?")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                StatRow(icon: "exclamationmark.triangle.fill", color: .orange,
                        text: "Unused apps can contain security vulnerabilities")
                StatRow(icon: "lock.slash.fill", color: .red,
                        text: "Abandoned apps stop receiving security patches")
                StatRow(icon: "externaldrive.badge.exclamationmark", color: .purple,
                        text: "Average user has 40+ unused apps taking up space")
                StatRow(icon: "hand.raised.slash.fill", color: .blue,
                        text: "Some apps request unnecessary permissions")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Views

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline.bold())

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
