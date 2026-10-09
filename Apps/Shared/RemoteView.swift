import BulbCore
import SwiftUI

struct RemoteView: View {
    @Bindable var remote: BulbRemote
    let controller: SimulatedBulbController?
    var deviceName: String = "Wipro bulb"
    @State var scenario: SimulationScenario
    @State private var showsDetails = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var recoveryDetailSize = 12.0
    @FocusState private var crownIsFocused: Bool

    private var crown: Binding<Double> {
        Binding(get: { remote.crownValue }, set: { remote.selectBrightness($0) })
    }

    var body: some View {
        content
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsDetails = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(deviceName)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wipro bulb, connection details")
                    .accessibilityIdentifier("connectionDetailsButton")
                }
            }
            .navigationDestination(isPresented: $showsDetails) {
                ConnectionView(remote: remote, controller: controller, scenario: $scenario, deviceName: deviceName)
            }
            .task {
                await remote.activate()
                restoreCrownFocus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await remote.activate(); restoreCrownFocus() }
                } else {
                    remote.deactivate()
                    crownIsFocused = false
                }
            }
            .onChange(of: showsDetails) { _, shown in
                if !shown { restoreCrownFocus() }
            }
            .onChange(of: remote.canSelectBrightness) { _, allowed in
                crownIsFocused = allowed && !showsDetails
            }
    }

    @ViewBuilder private var content: some View {
        switch remote.status {
        case .connecting, .stale:
            message(icon: "arrow.trianglehead.2.clockwise", title: "Reading your light", detail: "Getting the current power and brightness.", action: nil)
        case .cooldown:
            message(icon: "clock", title: "Cooling down", detail: "Wait before checking the bulb again.", action: "Check status")
        case .setupRequired(let failure):
            failureView(failure)
        case .unconfirmed:
            message(icon: "exclamationmark.triangle", title: "Not confirmed", detail: "Your change may have reached the bulb.", action: "Check status")
        case .failed(let failure):
            failureView(failure)
        case .ready, .updating:
            controls
        }
    }

    private var controls: some View {
        GeometryReader { geometry in
            let simplified = dynamicTypeSize >= .xxxLarge
            VStack(spacing: 5) {
                crownDial(simplified: simplified)
                    .frame(maxHeight: .infinity)
                if !simplified {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(BulbTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                #if os(iOS)
                Slider(value: crown, in: 10...100, step: 1) { editing in
                    if !editing { Task { await remote.commitBrightness() } }
                }
                .tint(BulbTheme.amber)
                .disabled(!remote.canSelectBrightness)
                .accessibilityLabel("Brightness selection")
                #endif
                powerButton
            }
            .padding(.horizontal, geometry.size.width < 190 ? 8 : 12)
            .padding(.bottom, 8)
        }
    }

    private func crownDial(simplified: Bool) -> some View {
        let dial = BrightnessDial(
            value: remote.displayedBrightness,
            caption: dialCaption,
            isOn: remote.reportedState?.isOn == true,
            hasSelection: remote.selection != nil,
            isPending: remote.status == .updating,
            simplified: simplified
        )
        #if os(watchOS)
        return dial
            .accessibilityIdentifier("brightnessDial")
            .focusable(remote.canSelectBrightness)
            .focused($crownIsFocused)
            .digitalCrownRotation(
                detent: crown, from: 10, through: 100, by: 1,
                sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true,
                onIdle: { Task { await remote.commitBrightness() } }
            )
        #else
        return dial
        #endif
    }

    private var dialCaption: String {
        if remote.isPowerPending { return "Requested" }
        if remote.isBrightnessPending { return "Setting…" }
        if remote.selection != nil, remote.reportedState?.isOn == false { return "Next time" }
        if remote.selection != nil { return "Selected" }
        return remote.reportedState?.isOn == true ? "On" : "Off"
    }

    private var hint: String {
        if remote.reportedState?.mode != .white { return "Choose White in Smart Life to dim" }
        if remote.isPowerPending { return remote.reportedState?.isOn == true ? "Turning off…" : "Turning on…" }
        if remote.reportedState?.isOn == false { return remote.selection == nil ? "Bulb is off" : "Bulb stays off" }
        #if os(watchOS)
        return "Turn Crown to dim"
        #else
        return "Choose brightness below"
        #endif
    }

    private var powerLabel: String {
        let isOn = remote.reportedState?.isOn == true
        if remote.isPowerPending { return isOn ? "Turning off…" : "Turning on…" }
        return isOn ? "Turn off" : "Turn on"
    }

    private var powerButton: some View {
        let usesAmber = remote.reportedState?.isOn == false && !remote.isBusy
        return Button {
            Task { await remote.togglePower(); restoreCrownFocus() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "power")
                Text(powerLabel).fontWeight(.semibold)
            }
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(usesAmber ? BulbTheme.ink : remote.canTogglePower ? .white : BulbTheme.muted)
            .background(usesAmber ? BulbTheme.amber : BulbTheme.raised, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!remote.canTogglePower)
        .accessibilityIdentifier("powerButton")
    }

    @ViewBuilder private func failureView(_ failure: BulbFailure) -> some View {
        switch failure {
        case .offline:
            message(icon: "wifi.slash", title: "Bulb is offline", detail: "Check its power and Wi-Fi, then try again.", action: "Refresh")
        case .timedOut:
            message(icon: "clock", title: "Connection timed out", detail: "Check your connection and read the bulb again.", action: "Check status")
        case .rejected:
            message(icon: "exclamationmark.triangle", title: "Change failed", detail: "The bulb did not accept this command.", action: "Refresh")
        case .unsupportedBrightness:
            message(icon: "sun.max", title: "Unsupported brightness", detail: "The bulb reports an unexpected brightness range.", action: "Refresh")
        case .authentication:
            message(icon: "key", title: "Replace your key", detail: "Open Bulb Assist on iPhone to replace the API key.", action: nil)
        case .rateLimited:
            message(icon: "clock", title: "Cooling down", detail: "Wait before checking the bulb again.", action: "Check status")
        case .missingDevice:
            message(icon: "lightbulb", title: "Bulb unavailable", detail: "Select your bulb again on iPhone.", action: nil)
        case .unsupportedSchema:
            message(icon: "sun.max", title: "Unsupported bulb", detail: "Choose a compatible bulb on iPhone.", action: nil)
        case .transport, .uncertainWrite:
            message(icon: "exclamationmark.triangle", title: "Not confirmed", detail: "Read the bulb before trying another change.", action: "Check status")
        case .failed:
            message(icon: "exclamationmark.triangle", title: "Connection failed", detail: "Read the current bulb state before trying again.", action: "Refresh")
        }
    }

    private func message(icon: String, title: String, detail: String, action: String?) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: icon).font(.title2).foregroundStyle(BulbTheme.amber).accessibilityHidden(true)
                    Text(title).font(.headline).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(.system(size: recoveryDetailSize)).foregroundStyle(BulbTheme.muted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let action {
                        Button { Task { await remote.refresh(); restoreCrownFocus() } } label: {
                            Label(action, systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(BulbTheme.raised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recoveryButton")
                    } else {
                        Text(remote.status == .connecting || remote.status == .stale ? "Connecting…" : "Open Bulb Assist on iPhone").font(.caption).foregroundStyle(BulbTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .frame(minHeight: max(0, geometry.size.height - 8))
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 12)
        }
    }

    private func restoreCrownFocus() {
        crownIsFocused = remote.canSelectBrightness && !showsDetails
    }
}
