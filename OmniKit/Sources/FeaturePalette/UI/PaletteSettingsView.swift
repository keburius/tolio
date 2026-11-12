import OmniCore
import OmniPlatform
import SwiftUI

/// Settings for the Launcher.
struct PaletteSettingsView: View {
    let feature: PaletteFeature
    let settings: SettingsStore

    var body: some View {
        LabeledContent(L10n.Launcher.appsFound) {
            HStack {
                Text("\(feature.appCount)").monospacedDigit()
                Button(L10n.Launcher.findAgain) { feature.rebuildIndex() }
            }
        }
        .settingsAnchor(PaletteAnchor.apps)
        if let ms = feature.lastOpenMilliseconds {
            LabeledContent(L10n.Launcher.lastOpenTime) { Text(L10n.Launcher.milliseconds(ms)).monospacedDigit() }
        }
        Toggle(L10n.Launcher.downloadRates, isOn: settings.binding(PaletteFeature.currencyFetchKey))
            .settingsAnchor(PaletteAnchor.currencyFetch)
        Text(L10n.Launcher.downloadRatesHelp)
            .font(.caption).foregroundStyle(.secondary)
        LabeledContent(L10n.Launcher.defaultCurrency) {
            TextField(L10n.Launcher.defaultCurrency, text: Binding(
                get: { settings.value(PaletteFeature.defaultCurrencyKey) },
                set: { settings.set(String($0.uppercased().prefix(3)), for: PaletteFeature.defaultCurrencyKey) }
            ))
            .labelsHidden()
            .frame(width: 60)
            .multilineTextAlignment(.trailing)
        }
        .settingsAnchor(PaletteAnchor.defaultCurrency)
        ForEach(feature.rateStores, id: \.source.name) { store in
            RateStatusRow(store: store, fetchEnabled: settings.value(PaletteFeature.currencyFetchKey))
        }
        Button(L10n.Launcher.clearUsage) { feature.clearUsage() }
            .help(L10n.Launcher.clearUsageHelp)
            .settingsAnchor(PaletteAnchor.clearUsage)
    }
}

private struct RateStatusRow: View {
    let store: CurrencyRateStore
    let fetchEnabled: Bool

    var body: some View {
        LabeledContent(store.source.name) {
            HStack {
                if let current = store.rates {
                    Text(L10n.Launcher.ratesStatus(date: current.date, currencies: current.rates.count))
                } else {
                    Text(L10n.Launcher.notDownloaded).foregroundStyle(.secondary)
                }
                Button(store.isFetching ? L10n.Launcher.updating : L10n.Launcher.updateNow) {
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
