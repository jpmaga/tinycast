import AppKit

/// The editor uses styles one step up because a note is for reading.
@MainActor
struct NoteMarkdownTypography {
    static let standard = NoteMarkdownTypography(metrics: .standard)

    let body: NSFont
    let heading1: NSFont
    let heading2: NSFont
    let heading3: NSFont
    let caption: NSFont
    let codeBlock: NSFont
    static let hidden = NSFont.systemFont(ofSize: 0.01)

    init(metrics: InterfaceMetrics) {
        let typography = metrics.typography
        body = typography.textNSFont(.title3, weight: .regular)
        heading1 = typography.textNSFont(.largeTitle, weight: .bold)
        heading2 = typography.textNSFont(.title1, weight: .bold)
        heading3 = typography.textNSFont(.title2, weight: .semibold)
        caption = typography.textNSFont(.caption1, weight: .regular)
        codeBlock = NSFont.monospacedSystemFont(ofSize: body.pointSize - 1, weight: .regular)
    }

    func heading(_ level: Int) -> NSFont {
        switch level {
        case 1: heading1
        case 2: heading2
        default: heading3
        }
    }

    static func adding(_ traits: NSFontDescriptor.SymbolicTraits, to font: NSFont) -> NSFont {
        let current = font.fontDescriptor.symbolicTraits
        let requested = current.union(traits)
        let descriptor = font.fontDescriptor.withSymbolicTraits(requested)
        if let face = NSFont(descriptor: descriptor, size: font.pointSize),
            face.familyName == font.familyName,
            face.fontDescriptor.symbolicTraits.isSuperset(of: requested)
        {
            return face
        }
        let fallback = NSFont.systemFont(ofSize: font.pointSize, weight: requested.contains(.bold) ? .bold : .regular)
        guard requested.contains(.italic) else { return fallback }
        let italic = fallback.fontDescriptor.withSymbolicTraits(fallback.fontDescriptor.symbolicTraits.union(.italic))
        return NSFont(descriptor: italic, size: font.pointSize) ?? fallback
    }
}
