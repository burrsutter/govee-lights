import SwiftUI
import AppKit

struct GoveeLightControlView: View {
    let device: GoveeDevice
    var alwaysExpanded = false
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
        Group {
            if alwaysExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    if device.isReachable { controls } else { offline }
                }
            } else {
                DisclosureGroup {
                    if device.isReachable { controls.padding(.top, 4) } else { offline }
                } label: { header }
            }
        }
        .onAppear {
            brightness = Double(device.state.brightness)
            kelvin = Double(device.state.kelvin ?? 4000)
            if let c = device.state.color {
                color = Color(red: Double(c.r)/255, green: Double(c.g)/255, blue: Double(c.b)/255)
            }
        }
        .onChange(of: device.state.brightness) { _, v in if !isDraggingBrightness { brightness = Double(v) } }
        .onChange(of: device.state.kelvin) { _, v in if !isDraggingKelvin, let k = v { kelvin = Double(k) } }
    }

    private var header: some View {
        HStack {
            Circle().fill(device.isReachable ? (device.state.isOn ? .green : .gray) : .red).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).font(.subheadline)
                Text(device.ip).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if device.sku != nil { Text(device.sku!).font(.caption2).foregroundStyle(.secondary) }
            Button(device.state.isOn ? "ON" : "OFF") { Task { await manager.toggle(device.id) } }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.min").foregroundStyle(.secondary).font(.caption)
                Slider(value: $brightness, in: 0...100, step: 1) { editing in
                    isDraggingBrightness = editing
                    if !editing { Task { await manager.setBrightness(id: device.id, value: Int(brightness)) } }
                }
                Text("\(Int(brightness))%").font(.caption).monospacedDigit().frame(width: 36, alignment: .trailing).foregroundStyle(.secondary)
            }
            // Color + white controls
            HStack(spacing: 8) {
                ColorPicker("", selection: $color).labelsHidden().onChange(of: color) { _, _ in
                    // debounce: only send on explicit button to avoid spam; use Apply button
                }
                Button("Apply Color") { Task { await manager.setColor(id: device.id, color: rgb) } }
                    .buttonStyle(.bordered).controlSize(.small)
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "thermometer.snowflake").foregroundStyle(.secondary).font(.caption)
                Slider(value: $kelvin, in: 2000...9000, step: 100) { editing in
                    isDraggingKelvin = editing
                    if !editing { Task { await manager.setWhite(id: device.id, kelvin: Int(kelvin)) } }
                }
                Text("\(Int(kelvin))K").font(.caption).monospacedDigit().frame(width: 50, alignment: .trailing).foregroundStyle(.secondary)
            }
            HStack {
                Button("White 4000K") { Task { await manager.setWhite(id: device.id, kelvin: 4000) } }.buttonStyle(.borderless).font(.caption)
                Button("Warm 2700K") { Task { await manager.setWhite(id: device.id, kelvin: 2700) } }.buttonStyle(.borderless).font(.caption)
                Spacer()
            }
        }.padding(.leading, 4)
    }

    private var offline: some View {
        Text("Offline — check LAN Control is enabled in Govee app").font(.caption).foregroundStyle(.red)
    }
}
