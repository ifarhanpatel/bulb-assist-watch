import SwiftUI
import BulbCore

struct SetupView: View {
    @Bindable var setup: CompanionSetup
    var showsConnectionSettings = false
    var restoresOnAppear = true
    @State private var apiKey = ""
    @State private var showingRemoval = false
    @State private var showingKeyHelp = false
    @State private var showingSettings = false
    @State private var hasRestored = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showsConnectionSettings, case .connected = setup.stage {
                    settingsContent
                } else {
                    content
                }
                if let failure = setup.failure {
                    Label(failureText(failure), systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(BulbTheme.amber)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(BulbTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                if setup.isBusy { ProgressView().frame(maxWidth: .infinity) }
            }
            .padding(24)
        }
        .background(BulbTheme.phoneBackground)
        .navigationTitle(showsConnectionSettings ? "Connection" : "Bulb Assist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingSettings) {
            SetupView(setup: setup, showsConnectionSettings: true, restoresOnAppear: false)
        }
        .task {
            guard restoresOnAppear, !hasRestored else { return }
            hasRestored = true
            await setup.restore()
            await setup.retryDelivery()
        }
        .confirmationDialog("Remove connection?", isPresented: $showingRemoval, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await setup.remove() } }
            Button("Keep connection", role: .cancel) {}
        } message: {
            Text("This removes the saved key and bulb from your iPhone and Watch. Keep both apps open. Your bulb and Smart Life pairing stay as they are. The Tuya key remains active; revoke it separately in your Tuya account.")
        }
        .sheet(isPresented: $showingKeyHelp) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Use your existing Tuya End User API key linked to the Smart Life account that already controls your bulb.")
                        Text("You can create or manage this key in your Tuya account. Bulb Assist cannot create a key or pair a new bulb for you.")
                        Text("Paste the complete key into the secure field. Never share it in a screenshot or message.")
                    }.padding(24)
                }
                .navigationTitle("Where do I get a key?")
                .toolbar { Button("Done") { showingKeyHelp = false } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var content: some View {
        switch setup.stage {
        case .keyEntry, .discovering:
            heading(setup.isReplacing ? "Replace your key" : "Connect your bulb",
                    detail: setup.isReplacing ? "Enter a new Tuya API key. We’ll verify your bulb before updating Watch." : "Use the Tuya API key linked to your Smart Life account.", step: "1 OF 3")
            VStack(alignment: .leading, spacing: 12) {
                Text(setup.isReplacing ? "New API key" : "Tuya API key").font(.headline)
                SecureField("Paste your API key", text: $apiKey)
                    .accessibilityIdentifier("apiKeyField")
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(16).background(BulbTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.go)
                    .onSubmit { discover() }
                Text("Stored securely on your iPhone and Watch.").font(.footnote).foregroundStyle(BulbTheme.muted)
            }
            Button("Where do I get a key?") { showingKeyHelp = true }.frame(minHeight: 44)
            action(setup.isReplacing ? "Check new key" : "Find my bulb") { discover() }.accessibilityIdentifier("discoverDevicesButton")
            if setup.isReplacing { Button("Keep current connection") { apiKey = ""; setup.cancelReplacement() }.frame(minHeight: 44) }
            note("Your bulb should already work in Smart Life. This setup will not reset or re-pair it. Your light stays as it is during setup.")
        case .selection, .validating, .saving:
            heading("Choose your bulb", detail: setup.devices.isEmpty ? "No devices were found. Check the account linked to your key, then try again." : "Choose the light you want to control. We’ll check its power and brightness capabilities.", step: "2 OF 3")
            ForEach(setup.devices) { device in
                Button {
                    Task { await setup.select(device) }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "lightbulb").font(.title).foregroundStyle(BulbTheme.amber)
                        Text(device.name).font(.headline).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(BulbTheme.muted)
                    }.padding(20).frame(maxWidth: .infinity, minHeight: 64)
                        .background(BulbTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).disabled(setup.isBusy).accessibilityIdentifier(device.id)
            }
            Button("Use another key") { apiKey = ""; setup.cancelReplacement() }.frame(minHeight: 44).disabled(setup.isBusy)
            note("Power on or off. Brightness from 10–100% in white mode. Color and color temperature stay unchanged.")
        case .awaitingWatch, .verifyingWatch:
            heading("Finish on\nyour Watch", detail: "Open Bulb Assist on Apple Watch. Keep both apps open and your devices nearby.", step: "3 OF 3")
            status("Key saved on iPhone", detail: setup.selectedDevice?.name ?? "Your bulb has been selected.", complete: setup.hasSavedConfiguration)
            status(setup.watchPersisted ? "Key saved on Watch" : "Waiting for your Watch", detail: setup.watchPersisted ? "Watch storage is confirmed." : "Open the Watch app to continue.", complete: setup.watchPersisted)
            status("Check the bulb from Watch", detail: "A direct read confirms the connection.", complete: false)
            action("Try again") { Task { await setup.retryDelivery() } }
            management
            note("You can leave this screen and resume setup later.")
        case .connected(let snapshot):
            heading("Ready when\nyou are.", detail: "Your bulb is connected to Apple Watch. Everyday control is on your wrist.", step: "BULB ASSIST")
            status(setup.selectedDevice?.name ?? "Your bulb", detail: "Watch setup complete", complete: true)
            note(snapshot.mode == .white ? "Turn the Crown to choose brightness from 10–100%. While off, brightness stays local until you tap Turn on." : "Your bulb is outside white mode. Power remains available; switch to white mode in Smart Life for dimming.")
            action("Check connection") { Task { await setup.retryDelivery() } }
            Button { showingSettings = true } label: { Text("Connection settings").frame(minHeight: 54) }
                .accessibilityIdentifier("connectionSettingsButton")
            note("After setup, your Watch only needs an internet connection.")
        case .pendingRemoval:
            heading("Removal pending", detail: "The key is removed from this iPhone. Open Bulb Assist on Watch to finish deleting its saved connection.", step: "CONNECTION")
            action("Try again") { Task { await setup.retryDelivery() } }
            note("Removal stays pending until Watch confirms deletion. Your bulb stays as it is. The Tuya key remains active in your account.")
        case .removed:
            heading("Connection removed", detail: "Your iPhone and Watch have confirmed removal of the saved connection.", step: "CONNECTION")
            action("Set up my bulb") { setup.startAgain() }
            note("Your Smart Life pairing and bulb are unchanged. Revoke the API key separately in your Tuya account if needed.")
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Connection", detail: "Manage the bulb and key saved for your Watch.", step: "SETTINGS")
            status(setup.selectedDevice?.name ?? "Your bulb", detail: "Selected bulb", complete: true)
            status("API key saved", detail: "Hidden on both devices", complete: true)
            action("Check connection") { Task { await setup.retryDelivery() } }
            management
            note("Key changes finish when your Watch confirms them.")
        }
    }

    private var management: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Replace API key") { apiKey = ""; setup.beginReplacement() }.frame(minHeight: 44).accessibilityIdentifier("replaceKeyButton")
            Button("Remove connection", role: .destructive) { showingRemoval = true }.frame(minHeight: 44).accessibilityIdentifier("removeConnectionButton")
        }.disabled(setup.isBusy)
    }
    private func discover() {
        guard !setup.isBusy else { return }
        let key = apiKey
        apiKey = ""
        Task { await setup.discover(apiKey: key) }
    }
    private func heading(_ title: String, detail: String, step: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(step).font(.caption.weight(.semibold)).foregroundStyle(BulbTheme.muted)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text(detail).foregroundStyle(BulbTheme.muted)
        }
    }
    private func note(_ text: String) -> some View { Text(text).font(.footnote).foregroundStyle(BulbTheme.muted) }
    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(BulbTheme.ink).background(BulbTheme.amber, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(setup.isBusy)
    }
    private func status(_ title: String, detail: String, complete: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(complete ? BulbTheme.green : BulbTheme.muted)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(BulbTheme.muted)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(BulbTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func failureText(_ failure: SetupFailure) -> String {
        switch failure {
        case .invalidKey: "Check your API key. Paste the complete key or create a new one in your Tuya account."
        case .discovery: "Couldn’t find your devices. Check your internet connection and try again."
        case .unsupportedDevice: "This bulb does not expose compatible power and white-light brightness controls. Choose another bulb."
        case .unreachableWatch: "Your Watch is unavailable. Open both apps, keep them nearby, and try again."
        case .interrupted: "Setup was interrupted. Keep both apps open and try again."
        case .persistence: "Couldn’t securely save the connection. Unlock both devices and try again."
        case .staleRevision: "An outdated reply was ignored. Try again to check the current connection."
        case .bulb(.authentication): "Watch could not authenticate. Replace your API key."
        case .bulb(.rateLimited): "Tuya is limiting requests. Wait before checking again."
        case .bulb(.missingDevice): "The selected bulb is no longer available. Select it again with a valid key."
        case .bulb(.unsupportedSchema), .bulb(.unsupportedBrightness): "The bulb’s controls are unsupported. Select a compatible bulb."
        case .bulb(.offline): "The bulb reports offline. Check its power and Wi-Fi, then try again."
        case .bulb: "Watch could not read the bulb. Check its internet connection and try again."
        }
    }
}
