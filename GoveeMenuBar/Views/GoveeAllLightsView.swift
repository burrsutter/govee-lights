import SwiftUI
import AppKit

struct GoveeAllLightsView: View {
    @EnvironmentObject var manager: GoveeManager
    @State private var brightness: Double = 100
    @State private var kelvin: Double = 4000
    @State private var color: Color = .white
    @State private var isDraggingBrightness = false
    @State private var isDraggingKelvin = false

    private var rgb: RGBColor {
        let ns = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBColor(Int(r*255), Int(g*255), Int(b*255))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { manager.allOn }, set: { _ in Task { await manager.toggleAll() } })) {
                Text("All Govee Lights").font(.headline)
            }.toggleStyle(.switch)

            HStack(spacing: 6) {
                Image(systemName: "sun.min").foregroundStyle(.secondary)
                Slider(value: $brightness, in: 0...100, step: 1) { editing in
                    isDraggingBrightness = editing
                    if !editing { Task { await manager.setAllBrightness(Int(brightness)) } }
                }
                Image(systemName: "sun.max").foregroundStyle(.secondary)
                Text("\(Int(brightness))%").monospacedDigit().frame(width: 40, alignment: .trailing).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ColorPicker("Color", selection: $color).labelsHidden()
                Button("Apply to All") { Task { await manager.setAllColor(rgb) } }
                    .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button("White 4000K") { Task { await manager.setAllWhite(kelvin: Int(kelvin)) } }
                    .buttonStyle(.bordered).controlSize(.small)
            }

            HStack(spacing: 6) {
                Image(systemName: "thermometer.snowflake").foregroundStyle(.secondary)
                Slider(value: $kelvin, in: 2000...9000, step: 100) { editing in
                    isDraggingKelvin = editing
                    if !editing { Task { await manager.setAllWhite(kelvin: Int(kelvin)) } }
                }
                Image(systemName: "thermometer.sun").foregroundStyle(.secondary)
                Text("\(Int(kelvin))K").monospacedDigit().frame(width: 52, alignment: .trailing).foregroundStyle(.secondary)
            }
        }
    }
}
