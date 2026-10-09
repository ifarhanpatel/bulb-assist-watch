import BulbCore
import SwiftUI

@main
struct BulbAssistApp: App {
    @State private var prototype = Prototype()
    @State private var runtime = CompanionRuntime()
    @Environment(\.scenePhase) private var scenePhase
    private let arguments = ProcessInfo.processInfo.arguments

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if arguments.contains("--prototype") {
                    WelcomeView(prototype: prototype)
                } else if arguments.contains("--fixture-setup") || runtime.setup.hasSavedConfiguration
                            || runtime.setup.stage == .pendingRemoval || runtime.setup.stage == .removed {
                    SetupView(setup: runtime.setup)
                } else {
                    WelcomeView(prototype: prototype, setup: runtime.setup)
                }
            }
            .tint(BulbTheme.amber)
            .preferredColorScheme(.dark)
            .task { if !arguments.contains("--prototype") { await runtime.activate() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !arguments.contains("--prototype") {
                    Task { await runtime.activate() }
                }
            }
        }
    }
}
