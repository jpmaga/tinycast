import Foundation

enum InterfaceCornerRadius: String, CaseIterable, Identifiable, Sendable, SettingsFileRawValue {
    case square
    case subtle
    case `default`
    case round

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: String(localized: "Square")
        case .subtle: String(localized: "Subtle")
        case .default: String(localized: "Default")
        case .round: String(localized: "Round")
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .square: 0
        case .subtle: 0.5
        case .default: 1
        case .round: 1.3
        }
    }
}
