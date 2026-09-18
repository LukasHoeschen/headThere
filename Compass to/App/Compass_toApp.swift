import SwiftUI
import SwiftData

@main
struct Compass_toApp: App {
    @State private var locationManager = LocationManager()
    @State private var locationIdentity = LocationIdentity()
    @State private var pairingRouter = PairingRouter()
    @State private var purchaseManager = PurchaseManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TrackedItem.self])

        // Prefer iCloud sync; falls back to local if the CloudKit container
        // hasn't been enabled yet in Xcode → Signing & Capabilities → iCloud.
        let container: ModelContainer
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            container = cloudContainer
        } else {
            guard let local = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema)]
            ) else {
                fatalError("Could not create ModelContainer")
            }
            container = local
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(locationIdentity)
                .environment(pairingRouter)
                .environment(purchaseManager)
                .onOpenURL { url in
                    pairingRouter.handle(url)
                }
                .task {
                    locationManager.syncCoordinator = LocationSyncCoordinator(
                        modelContainer: sharedModelContainer,
                        identity: locationIdentity
                    )
                    try? await LocationSharingService(identity: locationIdentity).registerOwnPublicKey()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
