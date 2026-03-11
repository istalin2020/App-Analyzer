import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: AppOrganizerViewModel
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var scanLineOffset: CGFloat = -100
    @State private var currentStatus = "Initializing scan..."

    private let statusMessages = [
        "Discovering installed apps...",
        "Analyzing app permissions...",
        "Checking App Store ratings...",
        "Evaluating security risks...",
        "Detecting outdated apps...",
        "Scanning for vulnerabilities...",
        "Comparing app popularity...",
        "Finding duplicate apps...",
        "Generating recommendations...",
        "Finalizing results..."
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Scanner
            scannerAnimation

            // Progress Info
            progressInfo

            // Status Messages
            statusSection

            Spacer()

            // Safety Note
            safetyNote
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            startAnimations()
            startStatusUpdates()
        }
    }

    // MARK: - Scanner Animation

    private var scannerAnimation: some View {
        ZStack {
            // Outer pulse
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(pulseScale)

            // Middle ring
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                .frame(width: 160, height: 160)

            // Rotating scanner line
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(rotationAngle))

            // Inner circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Center icon
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                )
        }
    }

    // MARK: - Progress Info

    private var progressInfo: some View {
        VStack(spacing: 12) {
            Text("Scanning Your Apps")
                .font(.title2.bold())

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geometry.size.width * viewModel.analyzerService.scanProgress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.analyzerService.scanProgress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)

            Text("\(Int(viewModel.analyzerService.scanProgress * 100))%")
                .font(.headline)
                .foregroundStyle(.blue)
                .monospacedDigit()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.blue)
                Text(currentStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        }
        .frame(height: 30)
    }

    // MARK: - Safety Note

    private var safetyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.green)
            Text("Your data stays on your device. Nothing is shared.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    private func startStatusUpdates() {
        Task {
            for message in statusMessages {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation {
                    currentStatus = message
                }
            }
        }
    }
}
