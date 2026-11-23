import SwiftUI
import Synchronization

struct ThemePresentation: Equatable, Sendable {
    var dark = ThemePalette.baseline(.dark)
    var light = ThemePalette.baseline(.light)
    var windowOpacity: Double?
    var windowBlur = true

    func palette(for variant: ThemeVariant) -> ThemePalette {
        variant == .dark ? dark : light
    }
}

@MainActor
@Observable
final class ThemeRendering {
    static let shared = ThemeRendering()

    private nonisolated static let appKitSnapshot = Mutex(ThemePresentation())
    private(set) var presentation = ThemePresentation()

    private init() {}

    func apply(_ next: ThemePresentation) {
        guard next != presentation else { return }
        Self.appKitSnapshot.withLock { $0 = next }
        presentation = next
    }

    nonisolated static func appKitColor(_ color: Color) -> NSColor {
        NSColor(name: nil) { appearance in
            var environment = EnvironmentValues()
            environment.colorScheme = appearance.isDark ? .dark : .light
            environment.themePresentation = appKitSnapshot.withLock { $0 }
            var resolved = NSColor.clear
            appearance.performAsCurrentDrawingAppearance {
                resolved = NSColor(Color(color.resolve(in: environment)))
            }
            return resolved
        }
    }
}

extension ThemeColor {
    var swiftUI: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
}

extension EnvironmentValues {
    @Entry var themePresentation = ThemePresentation()

    var themePalette: ThemePalette {
        themePresentation.palette(for: colorScheme == .dark ? .dark : .light)
    }

    func appKitThemeColor(_ color: Color) -> NSColor {
        themePalette.isBaseline ? NSColor(color) : NSColor(Color(color.resolve(in: self)))
    }
}

extension View {
    func themeScope() -> some View {
        modifier(ThemeScope())
    }

    func themedGlass(
        _ glass: Glass = .regular, in shape: some Shape, tinted: Bool = false, fallback: Color? = nil
    ) -> some View {
        modifier(ThemeGlass(glass: glass, shape: shape, tinted: tinted, fallback: fallback))
    }
}

private struct ThemeScope: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let presentation = ThemeRendering.shared.presentation
        let palette = presentation.palette(for: colorScheme == .dark ? .dark : .light)
        content
            .foregroundStyle(palette.isBaseline ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.Colors.textPrimary))
            .tint(palette.accent?.swiftUI)
            .environment(\.themePresentation, presentation)
    }
}

private struct ThemeGlass<Surface: Shape>: ViewModifier {
    @Environment(\.themePresentation) private var presentation
    @Environment(\.colorScheme) private var colorScheme

    let glass: Glass
    let shape: Surface
    let tinted: Bool
    let fallback: Color?

    func body(content: Content) -> some View {
        let palette = presentation.palette(for: colorScheme == .dark ? .dark : .light)
        let effect =
            if tinted, let accent = palette.accent { glass.tint(accent.withAlpha(0.18).swiftUI) } else {
                glass
            }
        content
            .background {
                if !presentation.windowBlur, let fallback { shape.fill(fallback) }
            }
            .glassEffect(presentation.windowBlur ? effect : .identity, in: shape)
    }
}

struct ThemeColorStyle: ShapeStyle, Hashable {
    enum Rule: Hashable {
        case fixed
        case ink(dark: Double, light: Double, alternative: ThemeSlot?)
        case slot([ThemeSlot], alpha: Double? = nil)
        case accentInk(foregroundFallback: Bool = false)
        case opposingInk([ThemeSlot])
        case background
        case menuBackground
        case secondaryBackground(alpha: Double)
    }

    let baseline: Color
    let rule: Rule
    var customFallback: Color?

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let palette = environment.themePalette
        let opacity = environment.themePresentation.windowOpacity
        let blur = environment.themePresentation.windowBlur
        if palette.isBaseline {
            if case .background = rule, let opacity {
                return palette.background.withAlpha(opacity).swiftUI.resolve(in: environment)
            }
            if case .menuBackground = rule, opacity != nil || !blur {
                return palette.background.withAlpha(opacity ?? palette.background.alpha).swiftUI.resolve(
                    in: environment)
            }
            return baseline.resolve(in: environment)
        }
        let color: ThemeColor?
        switch rule {
        case .fixed:
            color = nil
        case .ink(let dark, let light, let alternative):
            let alpha = palette.variant == .dark ? dark : light
            color =
                alternative.flatMap { palette[$0] }
                ?? palette.foreground.withAlpha(palette.foreground.alpha * alpha)
        case .slot(let slots, let alpha):
            let first = slots.lazy.compactMap { palette[$0] }.first
            color = first.map { $0.withAlpha($0.alpha * (alpha ?? 1)) }
        case .accentInk(let foregroundFallback):
            color = palette.accentForeground ?? (foregroundFallback ? palette[.foreground]?.contrastingInk : nil)
        case .opposingInk(let slots):
            color = slots.lazy.compactMap { palette[$0] }.first?.contrastingInk
        case .background:
            color = palette.background.withAlpha(opacity ?? palette.background.alpha)
        case .menuBackground:
            let menu = palette[.menuBackground] ?? palette.secondaryBackground.withAlpha(palette.background.alpha)
            color = menu.withAlpha(opacity ?? menu.alpha)
        case .secondaryBackground(let alpha):
            color = palette.secondaryBackground.withAlpha(alpha)
        }
        return (color?.swiftUI ?? customFallback ?? baseline).resolve(in: environment)
    }
}
