import SwiftUI
import SwiftData

/// Decides whether to show the first-run onboarding or the main compass.
/// Installs from before onboarding existed (already have saved items) skip
/// straight to the app instead of being forced through it retroactively.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        // A one-shot count, not a live @Query — onboarding itself inserts
        // example places, and a live query would immediately mistake those
        // for pre-existing data and boot the user out of the flow mid-way.
        .onAppear {
            guard !hasCompletedOnboarding else { return }
            let count = try? modelContext.fetchCount(FetchDescriptor<TrackedItem>())
            if let count, count > 0 {
                hasCompletedOnboarding = true
            }
        }
    }
}
