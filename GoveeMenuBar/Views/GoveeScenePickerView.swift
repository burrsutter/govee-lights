import SwiftUI

struct GoveeScenePickerView: View {
    let presets: [GoveePreset]
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredPresets: [GoveePreset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return presets }
        return presets.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose a Scene").font(.headline)
                Spacer()
                Text("\(presets.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Search scenes", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if filteredPresets.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredPresets) { preset in
                            Button {
                                selection = preset.id
                                isPresented = false
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: preset.icon)
                                        .frame(width: 18)
                                        .foregroundStyle(.secondary)
                                    Text(preset.name)
                                        .lineLimit(1)
                                    Spacer()
                                    if selection == preset.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    selection == preset.id
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280, height: 300)
    }
}
