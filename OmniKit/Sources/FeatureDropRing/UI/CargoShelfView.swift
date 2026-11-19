import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The Cargo shelf: the collected files as a stack you drag out in one go.
struct CargoShelfView: View {
    let feature: DropRingFeature

    var body: some View {
        let urls = feature.cargo
        VStack(spacing: OmniStyle.s2) {
            HStack {
                Label(L10n.DropRing.cargo, systemImage: "shippingbox").font(.headline)
                Spacer()
                Button { feature.hideCargo() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel(L10n.Common.close)
            }
            if urls.isEmpty {
                Text(L10n.DropRing.cargoEmpty).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(Array(urls.suffix(5).enumerated()), id: \.offset) { index, url in
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 64, height: 64)
                            .rotationEffect(.degrees(Double(index - 2) * 6))
                            .offset(x: CGFloat(index - 2) * 10)
                    }
                    FileDragSource(urls: urls) { dropped in if dropped { feature.clearCargo() } }
                }
                .frame(height: 84)
                .help(L10n.DropRing.dragAllOut)
                Text("\(L10n.DropRing.items(urls.count)) · \(L10n.DropRing.dragAllOut)")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Button(L10n.DropRing.clearCargo) { feature.clearCargo() }
                    .controlSize(.small).help(L10n.DropRing.clearCargoHelp)
            }
        }
        .padding(OmniStyle.s3)
        .frame(width: 260, height: 210)
        .omniPanelBackground()
    }
}
