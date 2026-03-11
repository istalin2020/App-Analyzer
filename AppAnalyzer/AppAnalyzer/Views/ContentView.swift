import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppAnalyzerViewModel()

    var body: some View {
        Group {
            if !viewModel.hasCompletedOnboarding {
                OnboardingView(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreen)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.currentScreen {
        case .home:
            HomeView(viewModel: viewModel)
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
        case .categorySelection:
            CategorySelectionView(viewModel: viewModel)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        case .scanning:
            ScanningView(viewModel: viewModel)
                .transition(.opacity)
        case .results:
            ResultsView(viewModel: viewModel)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
        }
    }
}
