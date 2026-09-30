import SwiftUI
import SwiftData

/// A short, linear first-run flow: show what the compass looks like, explain
/// why location access is needed (before the system prompt fires), let the
/// user add a couple of example places for free, then explain how adding a
/// person via invite link works.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(LocationManager.self) private var locationManager
    @Environment(LocationIdentity.self) private var identity
    @Environment(\.modelContext) private var modelContext
    @Query private var existingItems: [TrackedItem]

    @State private var page = 0
    @State private var addedPlaceNames: Set<String> = []

    private let totalPages = 4

    private var pairingURL: URL {
        URL(string: "compassto://pair?code=\(identity.ownCode)")!
    }

    private let placeSuggestions: [(name: String, lat: Double, lon: Double, symbol: String)] = [
        ("North Pole", 90, 0, "snowflake"),
        ("Mount Everest", 27.9881, 86.9250, "mountain.2.fill"),
        ("Eiffel Tower", 48.8584, 2.2945, "building.columns.fill"),
        ("Sydney Opera House", -33.8568, 151.2153, "theatermasks.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 0)

            Group {
                switch page {
                case 0: welcomePage
                case 1: permissionPage
                case 2: placesPage
                default: peoplePage
                }
            }
            .id(page)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer(minLength: 0)

            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            Spacer()
            if page < totalPages - 1 {
                Button("Skip") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            OnboardingCompassPreview()
            VStack(spacing: 10) {
                Text("Always Know Which Way")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("HeadThere points you toward the places and people that matter — with live direction and distance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 2: Location permission

    private var permissionPage: some View {
        VStack(spacing: 28) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor.gradient)

            VStack(spacing: 10) {
                Text("We Need Your Location")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Your location powers everything HeadThere does.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                permissionReason(
                    icon: "location.north.line.fill",
                    title: "For the compass",
                    text: "Direction and distance to every place and person update live as you move."
                )
                permissionReason(
                    icon: "clock.arrow.circlepath",
                    title: "In the background too",
                    text: "So your Home Screen widget and the location you share with people keep updating even when HeadThere isn't open."
                )
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func permissionReason(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Page 3: Add example places

    private var placesPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Add a Few Places")
                    .font(.title.bold())
                Text("Places are always free — add as many as you like, whenever you like.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(placeSuggestions, id: \.name) { suggestion in
                    placeSuggestionRow(suggestion)
                }
            }
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func placeSuggestionRow(_ suggestion: (name: String, lat: Double, lon: Double, symbol: String)) -> some View {
        let added = addedPlaceNames.contains(suggestion.name)
        Button {
            addPlace(suggestion)
        } label: {
            HStack {
                Image(systemName: suggestion.symbol)
                    .frame(width: 22)
                Text(suggestion.name)
                Spacer()
                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(added ? .green : Color.accentColor)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(added)
        .foregroundStyle(.primary)
    }

    // MARK: - Page 4: Adding people

    private var peoplePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Share With Someone")
                    .font(.title.bold())
                Text("Send your invite link — they don't need to do anything else. Opening it starts sharing your location with them right away, and you automatically start receiving theirs too.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ShareLink(
                item: pairingURL,
                subject: Text("HeadThere"),
                message: Text("Add me in HeadThere so we can share locations.")
            ) {
                Label("Share My Invite Link", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Free includes \(freePersonLimit) person — Pro unlocks unlimited.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Continue button

    @ViewBuilder
    private var continueButton: some View {
        Button {
            advance()
        } label: {
            Text(continueTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var continueTitle: String {
        switch page {
        case 1: return "Enable Location Access"
        case totalPages - 1: return "Get Started"
        default: return "Continue"
        }
    }

    // MARK: - Actions

    private func advance() {
        if page == 1 {
            locationManager.requestPermission()
        }
        if page == totalPages - 1 {
            finish()
        } else {
            page += 1
        }
    }

    private func addPlace(_ suggestion: (name: String, lat: Double, lon: Double, symbol: String)) {
        guard !addedPlaceNames.contains(suggestion.name) else { return }
        let item = TrackedItem(
            name: suggestion.name,
            type: .location,
            latitude: suggestion.lat,
            longitude: suggestion.lon,
            colorHex: nextItemColor(count: existingItems.count + addedPlaceNames.count)
        )
        modelContext.insert(item)
        addedPlaceNames.insert(suggestion.name)
    }

    /// Reachable both from the last page's main button and from "Skip" on any
    /// earlier page — either way, permission still gets requested exactly once
    /// if the user never hit "Enable Location Access" directly.
    private func finish() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        hasCompletedOnboarding = true
    }
}

// MARK: - Compass preview

/// A decorative, non-interactive stand-in for the real compass — fixed sample
/// data, no location dependency — just to show what the app looks like before
/// permissions or real places exist yet.
private struct OnboardingCompassPreview: View {
    private struct Sample: Identifiable {
        let id = UUID()
        let name: String
        let distance: String
        let angle: Double
        let colorHex: String
    }

    private let samples: [Sample] = [
        Sample(name: "Berlin", distance: "482 km", angle: 35, colorHex: "#45B7D1"),
        Sample(name: "Mom", distance: "12 km", angle: 155, colorHex: "#FF6B6B"),
        Sample(name: "North Pole", distance: "3,110 km", angle: 265, colorHex: "#4ECDC4"),
    ]

    @State private var wobble = false

    var body: some View {
        ZStack {
            Circle().stroke(.gray.opacity(0.16), lineWidth: 0.75).frame(width: 230, height: 230)
            Circle().stroke(.gray.opacity(0.16), lineWidth: 0.75).frame(width: 150, height: 150)
            Circle().fill(.gray.opacity(0.5)).frame(width: 5, height: 5)

            ForEach(samples) { sample in
                arrow(for: sample)
            }
        }
        .frame(width: 250, height: 250)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                wobble = true
            }
        }
    }

    @ViewBuilder
    private func arrow(for sample: Sample) -> some View {
        let displayAngle = sample.angle + (wobble ? 4 : -4)
        let rad = displayAngle * .pi / 180
        let radius: CGFloat = 100
        let pos = CGSize(width: sin(rad) * radius, height: -cos(rad) * radius)

        VStack(spacing: 2) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 18, weight: .semibold))
                .rotationEffect(.degrees(displayAngle))
            Text(sample.name).font(.caption2.bold()).lineLimit(1)
            Text(sample.distance).font(.caption2).opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color(hex: sample.colorHex), in: RoundedRectangle(cornerRadius: 7))
        .offset(pos)
    }
}
