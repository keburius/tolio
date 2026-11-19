import OmniCore
import OmniPlatform
import SwiftUI

/// The example at the top of the Clipboard History page: the history panel
/// with seven copied items, the second one selected.
struct ClipboardHero: View {
    private typealias C = L10n.Clipboard

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        var picture: [Color]? = nil
        var selected = false
        var pinned = false
    }

    private var items: [Item] {
        [
            Item(id: 0, title: C.heroText1, subtitle: C.heroSubtitle(C.heroKindText, C.heroAppNotes)),
            Item(id: 1, title: C.heroPicture(1200, 800), subtitle: C.heroSubtitle(C.heroKindPicture, C.heroAppPreview),
                 picture: [Color(hex: 0xFF9500), Color(hex: 0xFF2D55)], selected: true),
            Item(id: 2, title: C.heroLink, subtitle: C.heroSubtitle(C.heroKindLink, C.heroAppSafari)),
            Item(id: 3, title: C.heroText2, subtitle: C.heroSubtitle(C.heroKindText, C.heroAppMail)),
            Item(id: 4, title: C.heroPicture(640, 360), subtitle: C.heroSubtitle(C.heroKindPicture, C.heroAppScreenshot),
                 picture: [Color(hex: 0x32ADE6), Color(hex: 0x5856D6)]),
            Item(id: 5, title: C.heroText3, subtitle: C.heroSubtitle(C.heroKindText, C.heroAppMessages), pinned: true),
            Item(id: 6, title: C.heroText4, subtitle: C.heroSubtitle(C.heroKindText, C.heroAppTerminal)),
        ]
    }

    var body: some View {
        ASStage(tint: AS.blue) {
            panel
                .padding(.top, 16)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            LinearGradient(stops: [.init(color: AS.stage.opacity(0), location: 0), .init(color: AS.stage, location: 0.9)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(C.heroDescription)
        .accessibilityAddTraits(.isImage)
    }

    private var panel: some View {
        VStack(spacing: 1) {
            ForEach(items) { row($0) }
        }
        .padding(8)
        .frame(width: 330)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AS.panel))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 18)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 10) {
            if let picture = item.picture {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: picture, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 27, height: 27)
                    .overlay { LineIcon(ASIcon.picture, size: 16, lineWidth: 1.6, color: .white) }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(AS.font(12.5, .medium))
                    .foregroundStyle(item.selected ? Color.white : AS.text)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(AS.font(11))
                    .foregroundStyle(item.selected ? Color.white.opacity(0.8) : AS.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.selected { KeyCap("↩") } // l10n-ignore
            if item.pinned { LineIcon(ASIcon.pin, size: 12, color: AS.textSecondary) }
        }
        .padding(.horizontal, 10)
        .frame(height: 37)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(item.selected ? AS.blue : .clear))
    }
}
