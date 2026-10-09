import BulbCore
import SwiftUI

@main
struct BulbAssistWatchApp: App {
    @State private var prototype = Prototype()
    @State private var runtime = WatchRuntime()
    @Environment(\.scenePhase) private var scenePhase
    private let arguments = ProcessInfo.processInfo.arguments

    private var usesPrototype: Bool {
        arguments.contains("--prototype") || arguments.contains("--off")
            || arguments.contains("--below-range") || arguments.contains("--color-mode")
            || arguments.contains(where: { $0.hasPrefix("--scenario=") })
    }

    var body: some Scene {
        WindowGroup {
            if arguments.contains("--large-text") {
                remoteScreen.dynamicTypeSize(.xxxLarge)
            } else {
                remoteScreen
            }
        }
    }

    private var remoteScreen: some View {
        NavigationStack {
            if usesPrototype {
                RemoteView(remote: prototype.remote, controller: prototype.controller, scenario: prototype.initialScenario)
            } else if let remote = runtime.remote {
                RemoteView(remote: remote, controller: nil, deviceName: runtime.deviceName, scenario: .normal)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.and.arrow.forward").font(.title2).foregroundStyle(BulbTheme.amber)
                        Text(setupTitle).font(.headline).multilineTextAlignment(.center)
                        Text(setupDetail).font(.caption).foregroundStyle(BulbTheme.muted).multilineTextAlignment(.center)
                        if runtime.isLoading { ProgressView() }
                        else if runtime.failure != nil {
                            Button("Try again") { Task { await runtime.start() } }.frame(minHeight: 44)
                        }
                    }.padding(12)
                }.navigationTitle("Bulb Assist")
            }
        }
        .tint(BulbTheme.amber)
        .task {
            if !usesPrototype {
                runtime.setForeground(scenePhase == .active)
                await runtime.start()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if !usesPrototype { runtime.setForeground(phase == .active) }
        }
    }
    private var setupTitle: String {
        if runtime.isLoading { return "Reading connection" }
        if runtime.failure == .authentication { return "Replace your key" }
        return runtime.failure == nil ? "Set up on iPhone" : "Connection unavailable"
    }
    private var setupDetail: String {
        if runtime.isLoading { return "Checking your saved bulb configuration." }
        if runtime.failure == .authentication { return "Open Bulb Assist on iPhone to replace your Tuya key." }
        if runtime.failure != nil { return "Check your connection or select the bulb again on iPhone." }
        return "Open Bulb Assist on iPhone, select your bulb, and keep both apps open to finish setup."
    }
}
