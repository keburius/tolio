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
        Toggle("Download currency rates", isOn: settings.binding(PaletteFeature.currencyFetchKey))
        Text("Omni's only network requests: one small public file from each bank below, at most every 6 hours, when you open the palette. Nothing is sent.")
            .font(.caption).foregroundStyle(.secondary)
        LabeledContent("Default target currency") {
            TextField("", text: Binding(
                get: { settings.value(PaletteFeature.defaultCurrencyKey) },
                set: { settings.set(String($0.uppercased().prefix(3)), for: PaletteFeature.defaultCurrencyKey) }
            ))
            .frame(width: 60)
            .multilineTextAlignment(.trailing)
        }
        ForEach(feature.rateStores, id: \.source.name) { store in
            RateStatusRow(store: store, fetchEnabled: settings.value(PaletteFeature.currencyFetchKey))
        }
        Button("Clear Usage History") { feature.clearUsage() }
    }
}

private struct RateStatusRow: View {
    let store: CurrencyRateStore
    let fetchEnabled: Bool

    var body: some View {
        LabeledContent(store.source.name) {
            HStack {
                if let current = store.rates {
                    Text("\(current.date) · \(current.rates.count) currencies")
                } else {
                    Text("Not downloaded").foregroundStyle(.secondary)
                }
                Button(store.isFetching ? "Updating…" : "Update Now") {
                    Task { await store.refresh() }
                }
                .disabled(store.isFetching || !fetchEnabled)
            }
        }
        if let error = store.lastError {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }
}
