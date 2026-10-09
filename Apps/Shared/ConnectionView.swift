import BulbCore
import SwiftUI

struct ConnectionView: View {
    @Bindable var remote: BulbRemote
    let controller: SimulatedBulbController?
    @Binding var scenario: SimulationScenario
    var deviceName: String = "Wipro NS9001"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(deviceName).font(.headline)
                Label(controller == nil ? "Direct Watch connection" : "Simulated bulb", systemImage: "lightbulb")
                    .font(.caption).foregroundStyle(BulbTheme.amber)
                Text(modeDescription)
                    .font(.caption).foregroundStyle(BulbTheme.muted)
                if let snapshot = remote.reportedState {
                    Text("Last read: \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(BulbTheme.muted)
                }
                Button {
                    Task { await remote.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(remote.isBusy)
                #if DEBUG
                if let controller {
                Divider()
                Picker("Simulation", selection: $scenario) {
                    ForEach(SimulationScenario.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                #if os(watchOS)
                .pickerStyle(.navigationLink)
                #endif
                .accessibilityIdentifier("simulationPicker")
                .onChange(of: scenario) { _, selected in
                    Task {
                        await controller.setScenario(selected)
                        await remote.refresh()
                    }
                }
                Text("These scenarios control only the simulated bulb.")
                    .font(.caption2).foregroundStyle(BulbTheme.muted)
                }
                NavigationLink("Measurements") {
                    measurementView
                }
                .accessibilityIdentifier("measurementsLink")
                #endif
            }
            .padding(.horizontal, 12)
        }
        .navigationTitle("Connection")
        .tint(BulbTheme.amber)
    }

    #if DEBUG
    private var measurementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("This session").font(.headline)
                Text("Reads: \(remote.measurements.readRequests)")
                Text("Writes: \(remote.measurements.writeRequests)")
                Text("API accepted: \(remote.measurements.acceptedWrites)")
                Text("Matching reads: \(remote.measurements.matchingReadbacks)")
                if let action = remote.measurements.lastAction {
                    Text(action).font(.headline)
                    Text(remote.measurements.lastResult ?? "Pending")
                    if let delay = remote.measurements.lastReadbackDelay {
                        Text("Readback: \(delay, specifier: "%.2f") s")
                    }
                }
                Text("Readback time starts at Crown idle or the power tap. Time visible lamp response separately. Counts exclude setup/model checks and include failed requests.")
                    .font(.caption2).foregroundStyle(BulbTheme.muted)
                Button("Reset counts") { remote.resetMeasurements() }
                    .disabled(remote.isBusy)
                    .accessibilityIdentifier("resetMeasurementsButton")
            }
            .font(.caption)
            .padding(.horizontal, 12)
        }
        .navigationTitle("Measurements")
    }
    #endif

    private var modeDescription: String {
        guard let state = remote.reportedState else { return "Mode not yet reported" }
        return state.mode == .white ? "White-light mode" : "Color mode: power only"
    }
}
