import SwiftUI

@main
struct LocationChangerApp: App {
    @StateObject private var provider = LocationProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(provider)
        }
    }
}
