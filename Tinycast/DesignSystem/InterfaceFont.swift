import AppKit

enum InterfaceFont {
    static let system = "system"

    @MainActor
    static func isAvailable(_ family: String) -> Bool {
        family == system || NSFontManager.shared.availableFontFamilies.contains(family)
    }

    @MainActor
    static func resolve(_ family: String, matching reference: NSFont) -> NSFont? {
        guard family != system else { return nil }
        let manager = NSFontManager.shared
        let weight = manager.weight(of: reference)
        guard let font = manager.font(
            withFamily: family, traits: .unitalicFontMask, weight: weight, size: reference.pointSize),
            font.familyName == family, manager.weight(of: font) == weight
        else { return nil }
        return font
    }
}
