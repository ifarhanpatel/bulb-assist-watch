import SwiftUI

struct BrightnessDial: View {
    let value: Double?
    let caption: String
    let isOn: Bool
    let hasSelection: Bool
    let isPending: Bool
    let simplified: Bool

    private var valueText: String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var accent: Color {
        isOn || hasSelection ? BulbTheme.amber : BulbTheme.muted
    }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width - 26, geometry.size.height)
            let numberSize = simplified ? 48.0 : min(44, diameter * 0.46)
            ZStack {
                if !simplified {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(BulbTheme.raised, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(126))
                    Circle()
                        .trim(from: 0, to: 0.8 * min(1, max(0, (value ?? 0) / 100)))
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(126))
                }
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(valueText)
                            .font(.system(size: numberSize, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .tracking(-2)
                        if value != nil {
                            Text("%")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(BulbTheme.muted)
                        }
                    }
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    Text(caption)
                        .font(simplified ? .body : .system(size: 12))
                        .foregroundStyle(isPending || hasSelection ? BulbTheme.amber : isOn ? BulbTheme.green : BulbTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 6)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .trailing) {
                if !simplified {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brightness")
        .accessibilityValue(value == nil ? "Unknown" : "\(valueText) percent, \(caption)")
    }
}
