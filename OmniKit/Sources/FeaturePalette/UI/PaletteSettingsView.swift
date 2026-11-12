import OmniCore
import OmniPlatform
import SwiftUI

/// Settings for the command palette.
struct PaletteSettingsView: View {
    let feature: PaletteFeature
    let settings: SettingsStore

    var body: some View {
        LabeledContent("Indexed apps") {
            HStack {
                Text("\(feature.appCount)").monospacedDigit()
                Button("Rescan") { feature.rebuildIndex() }
            }
        }
        if let ms = feature.lastOpenMilliseconds {
            LabeledContent("Last open time") { Text("\(ms, specifier: "%.1f") ms").monospacedDigit() }
        }
        Toggle("Download currency rates from the European Central Bank", isOn: settings.binding(PaletteFeature.currencyFetchKey))
        Text("The only network request Omni makes: one small file, at most every 6 hours, when you open the palette.")
            .font(.caption).foregroundStyle(.secondary)
        LabeledContent("Default target currency") {
            TextField("", text: Binding(
                get: { settings.value(PaletteFeature.defaultCurrencyKey) },
                set: { settings.set(String($0.uppercased().prefix(3)), for: PaletteFeature.defaultCurrencyKey) }
            ))
            .frame(width: 60)
            .multilineTextAlignment(.trailing)
        }
        if let rates = feature.rates {
            LabeledContent("Rates") {
                HStack {
                    if let current = rates.rates {
                        Text("ECB, \(current.date) · \(current.rates.count) currencies")
                    } else {
                        Text("Not downloaded").foregroundStyle(.secondary)
                    }
                    Button(rates.isFetching ? "Updating…" : "Update Now") {
                        Task { await rates.refresh() }
                    }
                    .disabled(rates.isFetching || !settings.value(PaletteFeature.currencyFetchKey))
                }
            }
            if let error = rates.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        Button("Clear Usage History") { feature.clearUsage() }
    }
}
