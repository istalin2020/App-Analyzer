import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AppOrganizerViewModel
    @State private var currentPage = 0
    @State private var animateContent = false

    private let pages: [(icon: String, title: String, description: String, color: Color)] = [
        ("shield.checkered", "Welcome to\nApp Organizer",
         "Your smart companion for keeping your iPhone clean, secure, and organized.",
         .blue),
        ("magnifyingglass.circle.fill", "Smart App Scanner",
         "We analyze your installed apps for security risks, poor ratings, outdated updates, and excessive permissions.",
         .purple),
        ("line.3.horizontal.decrease.circle.fill", "You're in Control",
         "Choose which categories to scan. Select which apps to remove. We only suggest — you decide what stays and what goes.",
         .green),
        ("lock.shield.fill", "Safe & Private",
         "All analysis happens on your device. We never collect, share, or upload any of your personal data.",
         .orange)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPage(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom Section
            VStack(spacing: 20) {
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[index].color : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 10 : 6, height: currentPage == index ? 10 : 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Action Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                    } else {
                        viewModel.completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [pages[currentPage].color, pages[currentPage].color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: pages[currentPage].color.opacity(0.3), radius: 10, y: 5)
                }

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        viewModel.completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func onboardingPage(_ page: (icon: String, title: String, description: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
    }
}
