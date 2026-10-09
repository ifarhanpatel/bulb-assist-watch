import SwiftUI
import BulbCore

struct WelcomeView: View {
    let prototype: Prototype
    var setup: CompanionSetup? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(BulbTheme.amber)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your light.\nA little closer.")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text("A simple remote for your Wipro bulb, right on your Apple Watch.")
                        .font(.body).foregroundStyle(BulbTheme.muted)
                }
                VStack(spacing: 0) {
                    feature(icon: "digitalcrown.horizontal.arrow.clockwise", title: "Turn the Crown", detail: "Choose brightness from 10–100%.")
                    Divider()
                    feature(icon: "power", title: "Tap for power", detail: "Use the on-screen Turn on or Turn off button.")
                    Divider()
                    feature(icon: "moon", title: "Choose now. Turn on later.", detail: "While off, brightness stays local until you tap Turn on.")
                }
                if let setup {
                    NavigationLink { SetupView(setup: setup) } label: {
                        Text("Set up my bulb").fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(BulbTheme.ink)
                            .background(BulbTheme.amber, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }
                NavigationLink {
                    RemoteView(remote: prototype.remote, controller: prototype.controller, scenario: prototype.initialScenario)
                        .frame(minHeight: 400)
                } label: {
                    HStack {
                        Text("Try the prototype").fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(BulbTheme.ink)
                    .background(BulbTheme.amber, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                Text("Try the controls with a simulated bulb, or connect your existing Tuya account for everyday Watch use.")
                    .font(.footnote).foregroundStyle(BulbTheme.muted)
            }
            .padding(24)
        }
        .background(BulbTheme.phoneBackground)
        .navigationTitle("Bulb Assist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func feature(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(BulbTheme.amber)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(BulbTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 18)
    }
}
