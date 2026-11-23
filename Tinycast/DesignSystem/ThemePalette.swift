import Foundation

enum ThemeVariant: String, CaseIterable, Sendable {
    case dark, light

    var defaultID: String {
        switch self {
        case .dark: "tinycast-dark"
        case .light: "tinycast-light"
        }
    }
}

struct ThemeColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(rgb: UInt32, alpha: Double = 1) {
        red = Double((rgb >> 16) & 0xFF) / 255
        green = Double((rgb >> 8) & 0xFF) / 255
        blue = Double(rgb & 0xFF) / 255
        self.alpha = alpha
    }

    init?(hex: String) {
        guard hex.first == "#" else { return nil }
        let digits = hex.dropFirst().utf8
        guard [3, 6, 8].contains(digits.count),
            digits.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
            ),
            let value = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        switch digits.count {
        case 3:
            let expanded = ((value >> 8) * 17 << 16) | (((value >> 4) & 0xF) * 17 << 8) | ((value & 0xF) * 17)
            self.init(rgb: expanded)
        case 8:
            self.init(rgb: value >> 8, alpha: Double(value & 0xFF) / 255)
        default:
            self.init(rgb: value)
        }
    }

    var hex: String {
        let components = alpha == 1 ? [red, green, blue] : [red, green, blue, alpha]
        return "#" + components.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    func withAlpha(_ alpha: Double) -> Self {
        Self(red: red, green: green, blue: blue, alpha: alpha)
    }

    func mixed(with other: Self, fraction: Double) -> Self {
        Self(
            red: red + (other.red - red) * fraction, green: green + (other.green - green) * fraction,
            blue: blue + (other.blue - blue) * fraction, alpha: alpha + (other.alpha - alpha) * fraction)
    }

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var contrastingInk: Self {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
        return Self(rgb: luminance > 0.179 ? 0x000000 : 0xFFFFFF)
    }
}

enum ThemeSlot: String, CaseIterable, Sendable {
    case accent, accentForeground = "accent_foreground"
    case background, foreground, secondaryBackground = "secondary_background", border
    case muted, danger, success, warning, placeholder, selection
    case blue, cyan, green, magenta, orange, purple, red, yellow
    case menuBackground = "menu_background"
    case syntaxKeyword = "syntax_keyword", syntaxString = "syntax_string", syntaxNumber = "syntax_number"
    case syntaxComment = "syntax_comment", syntaxType = "syntax_type", syntaxFunction = "syntax_function"
    case syntaxConstant = "syntax_constant", syntaxAttribute = "syntax_attribute", syntaxProperty =
        "syntax_property"
    case syntaxInserted = "syntax_inserted", syntaxDeleted = "syntax_deleted"
}

struct ThemePalette: Equatable, Sendable {
    let variant: ThemeVariant
    let isBaseline: Bool
    let overrides: [ThemeSlot: ThemeColor]

    static func baseline(_ variant: ThemeVariant) -> Self {
        Self(variant: variant, isBaseline: true, overrides: [:])
    }

    subscript(_ slot: ThemeSlot) -> ThemeColor? { overrides[slot] }

    var background: ThemeColor {
        self[.background] ?? Self.baselineBackground(variant)
    }

    var foreground: ThemeColor {
        self[.foreground] ?? ThemeColor(rgb: variant == .dark ? 0xFFFFFF : 0x000000)
    }

    var secondaryBackground: ThemeColor {
        self[.secondaryBackground]
            ?? background
            .mixed(with: foreground, fraction: variant == .dark ? 0.08 : 0.04)
            .withAlpha(background.alpha)
    }

    var accent: ThemeColor? { self[.accent] }

    var accentForeground: ThemeColor? { self[.accentForeground] ?? accent?.contrastingInk }

    static func baselineBackground(_ variant: ThemeVariant) -> ThemeColor {
        switch variant {
        case .dark: ThemeColor(rgb: 0x000000, alpha: 0.40)
        case .light: ThemeColor(rgb: 0xFFFFFF, alpha: 0.55)
        }
    }
}
