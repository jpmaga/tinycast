import Foundation

struct ThemeCatalog: Sendable {
    let definitions: [ThemeDefinition]
    let issues: [ThemeDefinition.Issue]
    private let byID: [String: ThemeDefinition]

    init(userDefinitions: [ThemeDefinition] = []) {
        var ordered: [ThemeDefinition] = []
        var indexed: [String: ThemeDefinition] = [:]
        var issues: [ThemeDefinition.Issue] = []
        for definition in Self.builtIns + userDefinitions {
            guard indexed[definition.id] == nil else {
                issues.append(.duplicateID(definition.id))
                continue
            }
            ordered.append(definition)
            indexed[definition.id] = definition
        }
        definitions = ordered
        byID = indexed
        self.issues = issues
    }

    func resolve(
        id: String, variant: ThemeVariant
    ) -> (palette: ThemePalette, issues: [ThemeDefinition.Issue]) {
        guard let definition = byID[id], definition.variant == variant else {
            return (.baseline(variant), [.unavailableSelection(id: id, variant: variant)])
        }
        if id == variant.defaultID { return (.baseline(variant), []) }

        var issues: [ThemeDefinition.Issue] = []
        var colors: [ThemeSlot: ThemeColor] = [:]
        var visited: Set<String> = []
        var path: [String] = []
        var current = definition
        while visited.insert(current.id).inserted {
            path.append(current.id)
            colors.merge(current.colors) { child, _ in child }
            guard let parentID = current.inherits else { break }
            guard let parent = byID[parentID] else {
                issues.append(.missingParent(theme: current.id, parent: parentID))
                break
            }
            guard parent.variant == variant else {
                issues.append(.incompatibleParent(theme: current.id, parent: parentID))
                break
            }
            guard !visited.contains(parentID) else {
                issues.append(.cycle(path + [parentID]))
                break
            }
            current = parent
        }
        let isBaseline = current.id == variant.defaultID && colors.isEmpty
        return (ThemePalette(variant: variant, isBaseline: isBaseline, overrides: colors), issues)
    }

    static let builtIns: [ThemeDefinition] = [
        ThemeDefinition(id: ThemeVariant.dark.defaultID, name: "Tinycast Dark", variant: .dark),
        ThemeDefinition(id: ThemeVariant.light.defaultID, name: "Tinycast Light", variant: .light),
        preset(
            "tokyo-night", "Tokyo Night", .dark, ground: 0x1A1B26, opacity: 0.58, ink: 0xC0CAF5,
            raised: 0x24283B, border: 0x3B4261, accent: 0x7AA2F7,
            colors: [.green: 0x9ECE6A, .red: 0xF7768E, .yellow: 0xE0AF68, .magenta: 0xBB9AF7, .cyan: 0x7DCFFF]
        ),
        preset(
            "catppuccin-mocha", "Catppuccin Mocha", .dark, ground: 0x1E1E2E, opacity: 0.58, ink: 0xCDD6F4,
            raised: 0x313244, border: 0x45475A, accent: 0xCBA6F7,
            colors: [.green: 0xA6E3A1, .red: 0xF38BA8, .yellow: 0xF9E2AF, .blue: 0x89B4FA, .cyan: 0x94E2D5]),
        preset(
            "catppuccin-latte", "Catppuccin Latte", .light, ground: 0xEFF1F5, opacity: 0.70, ink: 0x4C4F69,
            raised: 0xE6E9EF, border: 0xBCC0CC, accent: 0x8839EF,
            colors: [.green: 0x40A02B, .red: 0xD20F39, .yellow: 0xDF8E1D, .blue: 0x1E66F5, .cyan: 0x179299]),
        preset(
            "gruvbox-dark", "Gruvbox Dark", .dark, ground: 0x282828, opacity: 0.60, ink: 0xEBDBB2,
            raised: 0x3C3836, border: 0x504945, accent: 0xFABD2F,
            colors: [.green: 0xB8BB26, .red: 0xFB4934, .blue: 0x83A598, .purple: 0xD3869B, .cyan: 0x8EC07C]),
        preset(
            "gruvbox-light", "Gruvbox Light", .light, ground: 0xFBF1C7, opacity: 0.70, ink: 0x3C3836,
            raised: 0xEBDBB2, border: 0xD5C4A1, accent: 0xB57614,
            colors: [.green: 0x79740E, .red: 0x9D0006, .blue: 0x076678, .purple: 0x8F3F71, .cyan: 0x427B58]),
        preset(
            "nord", "Nord", .dark, ground: 0x2E3440, opacity: 0.64, ink: 0xECEFF4,
            raised: 0x3B4252, border: 0x4C566A, accent: 0x88C0D0,
            colors: [.green: 0xA3BE8C, .red: 0xBF616A, .yellow: 0xEBCB8B, .blue: 0x81A1C1, .purple: 0xB48EAD]),
        preset(
            "rose-pine", "Rosé Pine", .dark, ground: 0x191724, opacity: 0.59, ink: 0xE0DEF4,
            raised: 0x1F1D2E, border: 0x524F67, accent: 0xEBBCBA,
            colors: [.green: 0x95B1AC, .red: 0xEB6F92, .yellow: 0xF6C177, .cyan: 0x9CCFD8, .purple: 0xC4A7E7]),
        preset(
            "rose-pine-dawn", "Rosé Pine Dawn", .light, ground: 0xFAF4ED, opacity: 0.70, ink: 0x464261,
            raised: 0xFFFAF3, border: 0xCECACD, accent: 0xB4637A,
            colors: [.green: 0x6D8F89, .red: 0xB4637A, .yellow: 0xEA9D34, .cyan: 0x56949F, .purple: 0x907AA9]),
        preset(
            "kanagawa", "Kanagawa", .dark, ground: 0x1F1F28, opacity: 0.60, ink: 0xDCD7BA,
            raised: 0x2A2A37, border: 0x54546D, accent: 0x7E9CD8,
            colors: [.green: 0x76946A, .red: 0xE82424, .yellow: 0xE6C384, .cyan: 0x7FB4CA, .purple: 0x957FB8]),
        preset(
            "everforest-dark", "Everforest Dark", .dark, ground: 0x2D353B, opacity: 0.64, ink: 0xD3C6AA,
            raised: 0x343F44, border: 0x475258, accent: 0xA7C080,
            colors: [.green: 0xA7C080, .red: 0xE67E80, .yellow: 0xDBBC7F, .blue: 0x7FBBB3, .purple: 0xD699B6]),
        preset(
            "dracula", "Dracula", .dark, ground: 0x282A36, opacity: 0.62, ink: 0xF8F8F2,
            raised: 0x44475A, border: 0x6272A4, accent: 0xBD93F9,
            colors: [.green: 0x50FA7B, .red: 0xFF5555, .yellow: 0xF1FA8C, .cyan: 0x8BE9FD, .magenta: 0xFF79C6]
        ),
        preset(
            "solarized-light", "Solarized Light", .light, ground: 0xFDF6E3, opacity: 0.74, ink: 0x586E75,
            raised: 0xEEE8D5, border: 0x93A1A1, accent: 0x268BD2,
            colors: [.green: 0x859900, .red: 0xDC322F, .yellow: 0xB58900, .cyan: 0x2AA198, .purple: 0x6C71C4]),
        preset(
            "matte-black", "Matte Black", .dark, ground: 0x121212, opacity: 0.58, ink: 0xBEBEBE,
            raised: 0x333333, border: 0x515151, accent: 0xE68E0D,
            colors: [.green: 0xFFC107, .red: 0xD35F5F, .yellow: 0xFFC107, .purple: 0xD35F5F])
    ]

    private static func preset(
        _ id: String, _ name: String, _ variant: ThemeVariant, ground: UInt32, opacity: Double,
        ink: UInt32, raised: UInt32, border: UInt32, accent: UInt32, colors: [ThemeSlot: UInt32]
    ) -> ThemeDefinition {
        var slots = colors.mapValues { ThemeColor(rgb: $0) }
        slots[.background] = ThemeColor(rgb: ground, alpha: opacity)
        slots[.foreground] = ThemeColor(rgb: ink)
        slots[.secondaryBackground] = ThemeColor(rgb: raised)
        slots[.border] = ThemeColor(rgb: border)
        slots[.accent] = ThemeColor(rgb: accent)
        return ThemeDefinition(id: id, name: name, variant: variant, colors: slots)
    }
}
