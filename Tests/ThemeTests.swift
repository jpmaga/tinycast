import AppKit
import SwiftUI
import Synchronization

@main
@MainActor
struct ThemeTests {
    static var failures = 0
    static var passes = 0

    static func check(_ label: String, _ passed: Bool) {
        if passed {
            passes += 1
        } else {
            failures += 1
            print("FAIL  \(label)")
        }
    }

    static func main() {
        hex()
        decoding()
        inheritance()
        defaults()
        rendering()
        hostedForeground()

        print("\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func hex() {
        check("short hex expands", ThemeColor(hex: "#aC2")?.hex == "#AACC22")
        check("RGB is opaque", ThemeColor(hex: "#123abc") == ThemeColor(rgb: 0x123ABC))
        check("RGBA keeps its alpha", ThemeColor(hex: "#123ABC80")?.hex == "#123ABC80")
        check("transparent RGB keeps its components", ThemeColor(hex: "#13579B00")?.hex == "#13579B00")
        for invalid in ["fff", "#1234", "#+ab", "#1_2", "#zzzzzz", "#１２３", "#1234567", "#123456789"] {
            check("reject \(invalid)", ThemeColor(hex: invalid) == nil)
        }
    }

    static func decoding() {
        let input = """
            {
              "id": "custom", "name": "Custom", "variant": "dark", "inherits": "nord",
              "unknown": true,
              "colors": { "accent": "#abc", "selection": 42, "row_hover": "#12345678", "oops": "#fff" }
            }
            """
        let result = ThemeDefinition.decode(Data(input.utf8))
        check(
            "metadata survives", result.definition?.inherits == "nord" && result.definition?.variant == .dark)
        check(
            "valid colours survive",
            result.definition?.colors == [.accent: ThemeColor(rgb: 0xAABBCC)])
        check(
            "unknown and invalid keys reported",
            result.issues == [
                .unknownKey("unknown"), .unknownKey("colors.oops"), .unknownKey("colors.row_hover"),
                .invalidColor("colors.selection")
            ])
        let keys: Set<String> = [
            "accent", "accent_foreground", "background", "foreground", "secondary_background", "border",
            "muted", "placeholder", "selection", "danger", "success", "warning",
            "blue", "cyan", "green", "magenta", "orange", "purple", "red", "yellow", "menu_background",
            "syntax_keyword", "syntax_string", "syntax_number", "syntax_comment", "syntax_type", "syntax_function",
            "syntax_constant", "syntax_attribute", "syntax_property", "syntax_inserted", "syntax_deleted"
        ]
        let colors = keys.map { "\"\($0)\": \"#12345678\"" }.joined(separator: ", ")
        let semantic = ThemeDefinition.decode(
            Data(#"{"id":"semantic","name":"Semantic","variant":"dark","colors":{\#(colors)}}"#.utf8))
        let decoded = semantic.definition?.colors ?? [:]
        check("theme keys match the file format", Set(ThemeSlot.allCases.map(\.rawValue)) == keys)
        check("every semantic colour decodes with its alpha",
            semantic.issues.isEmpty && Set(decoded.keys.map(\.rawValue)) == keys
                && decoded.values.allSatisfy { $0.hex == "#12345678" })
        for malformed in ["[]", "{", "null"] {
            let result = ThemeDefinition.decode(Data(malformed.utf8))
            check("discard invalid JSON", result.definition == nil && result.issues == [.invalidJSON])
        }
        let invalidVariant = ThemeDefinition.decode(Data(#"{"id":"x","name":"X","variant":"sepia"}"#.utf8))
        check(
            "variant required",
            invalidVariant.definition == nil && invalidVariant.issues == [.invalidField("variant")])
        let badOptional = ThemeDefinition.decode(
            Data(#"{"id":"x","name":"X","variant":"light","colors":[]}"#.utf8))
        check(
            "bad optional object leaves defaults",
            badOptional.definition?.colors == [:]
                && badOptional.issues == [.invalidField("colors")])
    }

    static func inheritance() {
        let background = ThemeColor(rgb: 0x123456, alpha: 0.5)
        let parent = ThemeDefinition(
            id: "parent", name: "Parent", variant: .dark, inherits: "nord",
            colors: [.background: background])
        let child = ThemeDefinition(
            id: "child", name: "Child", variant: .dark, inherits: "parent",
            colors: [.accent: ThemeColor(rgb: 0xF0F0F0)])
        let shadow = ThemeDefinition(id: "nord", name: "Shadow", variant: .dark)
        let catalog = ThemeCatalog(userDefinitions: [parent, child, shadow])
        let resolved = catalog.resolve(id: "child", variant: .dark)
        check("child overrides parent", resolved.palette.accent == child.colors[.accent])
        check("parent background inherited", resolved.palette.background == background)
        check("grandparent foreground inherited", resolved.palette.foreground == ThemeColor(rgb: 0xECEFF4))
        check("accent ink follows contrast", resolved.palette.accentForeground == ThemeColor(rgb: 0x000000))
        check("built-in IDs are reserved", catalog.issues == [.duplicateID("nord")])
        check("built-in preset count", ThemeCatalog.builtIns.count == 15)

        let cycleA = ThemeDefinition(id: "a", name: "A", variant: .dark, inherits: "b")
        let cycleB = ThemeDefinition(id: "b", name: "B", variant: .dark, inherits: "a")
        let missing = ThemeDefinition(id: "missing", name: "Missing", variant: .dark, inherits: "absent")
        let incompatible = ThemeDefinition(
            id: "incompatible", name: "Incompatible", variant: .dark,
            inherits: ThemeVariant.light.defaultID)
        let broken = ThemeCatalog(userDefinitions: [cycleA, cycleB, missing, incompatible])
        check(
            "cycle names the path",
            broken.resolve(id: "a", variant: .dark).issues == [.cycle(["a", "b", "a"])])
        check(
            "missing parent reported",
            broken.resolve(id: "missing", variant: .dark).issues == [
                .missingParent(theme: "missing", parent: "absent")
            ])
        check(
            "cross-variant inheritance reported",
            broken.resolve(id: "incompatible", variant: .dark).issues == [
                .incompatibleParent(theme: "incompatible", parent: ThemeVariant.light.defaultID)
            ])
        let wrongVariant = broken.resolve(id: "nord", variant: .light)
        check(
            "wrong variant falls back",
            wrongVariant.palette == .baseline(.light)
                && wrongVariant.issues == [.unavailableSelection(id: "nord", variant: .light)])
        check(
            "unknown selection falls back",
            broken.resolve(id: "unknown", variant: .dark).palette == .baseline(.dark))
        let fallback = broken.resolve(id: "missing", variant: .dark).palette
        check(
            "default ground and ink fill gaps",
            fallback.background == ThemePalette.baselineBackground(.dark)
                && fallback.foreground == ThemeColor(rgb: 0xFFFFFF)
                && fallback.secondaryBackground.alpha == fallback.background.alpha)
    }

    static func defaults() {
        let c = Theme.Colors.self
        let tokens: [(String, Color, Color, Color)] = [
            (
                "panelScrim", c.panelScrim, Color(.sRGB, white: 0, opacity: 0.40),
                Color(.sRGB, white: 1, opacity: 0.55)
            ),
            (
                "dialogDimming", c.dialogDimming, Color(.sRGB, white: 0, opacity: 0.34),
                Color(.sRGB, white: 0, opacity: 0.34)
            ),
            (
                "findMatch", c.findMatch, Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.32)),
                Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.4))
            ),
            (
                "findCurrent", c.findCurrent, Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.9)),
                Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.95))
            ),
            (
                "findCurrentInk", c.findCurrentInk, Color(.sRGB, white: 0, opacity: 1),
                Color(.sRGB, white: 0, opacity: 1)
            ),
            (
                "tooltipShadow", c.tooltipShadow, Color(.sRGB, white: 0, opacity: 0.18),
                Color(.sRGB, white: 0, opacity: 0.18)
            ),
            ("selection", c.selection, .white.opacity(0.10), .black.opacity(0.09)),
            ("rowHover", c.rowHover, .white.opacity(0.05), .black.opacity(0.045)),
            ("emojiCell", c.emojiCell, .white.opacity(0.045), .black.opacity(0.04)),
            ("emojiHoverBorder", c.emojiHoverBorder, .white.opacity(0.42), .black.opacity(0.34)),
            ("emojiSelectionBorder", c.emojiSelectionBorder, .white.opacity(0.92), .black.opacity(0.72)),
            (
                "emojiInnerBorder", c.emojiInnerBorder, Color(.sRGB, white: 0, opacity: 0.72),
                Color(.sRGB, white: 1, opacity: 0.72)
            ),
            ("menuHover", c.menuHover, .white.opacity(0.10), .black.opacity(0.09)),
            ("menuBackground", c.menuBackground, .clear, .clear),
            ("separator", c.separator, .white.opacity(0.10), .black.opacity(0.12)),
            ("controlSurface", c.controlSurface, .white.opacity(0.10), .black.opacity(0.08)),
            ("controlHover", c.controlHover, .white.opacity(0.16), .black.opacity(0.14)),
            ("controlPressed", c.controlPressed, .white.opacity(0.24), .black.opacity(0.20)),
            (
                "compactShortcutSelectionTint", c.compactShortcutSelectionTint,
                Color(.sRGB, white: 0.55, opacity: 1),
                Color(.sRGB, white: 0, opacity: 0.40)
            ),
            (
                "compactShortcutSelectedInk", c.compactShortcutSelectedInk,
                Color(.sRGB, white: 1, opacity: 1),
                Color(.sRGB, white: 1, opacity: 1)
            ),
            ("border", c.border, .white.opacity(0.20), .black.opacity(0.18)),
            ("textPrimary", c.textPrimary, .white.opacity(1.0), .black.opacity(1.0)),
            ("textSecondary", c.textSecondary, .white.opacity(0.60), .black.opacity(0.60)),
            ("textTertiary", c.textTertiary, .white.opacity(0.40), .black.opacity(0.42)),
            ("dragPreviewInk", c.dragPreviewInk, Color(nsColor: .labelColor), Color(nsColor: .labelColor)),
            ("caretInk", c.caretInk, .white, .white),
            ("controlAccent", c.controlAccent, .accentColor, .accentColor),
            ("accentInk", c.accentInk, .white, .white),
            ("linkInk", c.linkInk, Color(nsColor: .linkColor), Color(nsColor: .linkColor)),
            (
                "tooltipSurface", c.tooltipSurface, Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor)
            ),
            (
                "dragPreviewSurface", c.dragPreviewSurface, Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .controlBackgroundColor)
            ),
            ("menuSymbol", c.menuSymbol, .white.opacity(0.70), .black.opacity(0.70)),
            ("noteText", c.noteText, .white.opacity(0.90), .black.opacity(0.85)),
            ("iconPlaceholder", c.iconPlaceholder, .white.opacity(0.06), .black.opacity(0.06)),
            ("sheen", c.sheen, .white.opacity(0.04), .black.opacity(0.04)),
            ("cardFill", c.cardFill, .white.opacity(0.05), .black.opacity(0.04)),
            ("cardStroke", c.cardStroke, .white.opacity(0.10), .black.opacity(0.10)),
            (
                "layoutPreviewWindow", c.layoutPreviewWindow, Color(.sRGB, white: 1, opacity: 0.22),
                Color(.sRGB, white: 1, opacity: 0.28)
            ),
            (
                "layoutPreviewWindowSelected", c.layoutPreviewWindowSelected,
                Color(.sRGB, white: 1, opacity: 0.38),
                Color(.sRGB, white: 1, opacity: 0.44)
            ),
            (
                "layoutPreviewGround", c.layoutPreviewGround, Color(.sRGB, white: 0, opacity: 0.55),
                Color(.sRGB, white: 0, opacity: 0.50)
            ),
            (
                "roomPreviewDim", c.roomPreviewDim, Color(.sRGB, white: 0, opacity: 0.18),
                Color(.sRGB, white: 0, opacity: 0.18)
            ),
            (
                "roomCardFill", c.roomCardFill, Color(.sRGB, white: 0.16, opacity: 0.94),
                Color(.sRGB, white: 0.98, opacity: 0.94)
            ),
            ("roomCardStroke", c.roomCardStroke, Color.accentColor, Color.accentColor),
            (
                "roomCardShadow", c.roomCardShadow, Color(.sRGB, white: 0, opacity: 0.25),
                Color(.sRGB, white: 0, opacity: 0.25)
            ),
            ("roomCardDot", c.roomCardDot, .white.opacity(0.25), .black.opacity(0.25)),
            ("searchFlash", c.searchFlash, Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.35)),
            (
                "checkerLight", c.checkerLight, Color(.sRGB, white: 1, opacity: 0.22),
                Color(.sRGB, white: 1, opacity: 0.22)
            ),
            (
                "checkerDark", c.checkerDark, Color(.sRGB, white: 0, opacity: 0.22),
                Color(.sRGB, white: 0, opacity: 0.22)
            ),
            (
                "brand", c.brand, Color(red: 0.525, green: 0.231, blue: 1.0),
                Color(red: 0.525, green: 0.231, blue: 1.0)
            ),
            ("dropGuide", c.dropGuide, .white.opacity(0.35), .black.opacity(0.35)),
            ("dropGuideArmed", c.dropGuideArmed, Color.blue, Color.blue),
            ("primaryAction", c.primaryAction, Color.blue, Color.blue),
            ("destructive", c.destructive, Color.red, Color.red),
            ("success", c.success, Color.green, Color.green),
            ("warning", c.warning, Color.orange, Color.orange),
            ("composerSend", c.composerSend, .white.opacity(0.92), .black.opacity(0.92)),
            (
                "composerSendInk", c.composerSendInk, Color(.sRGB, white: 0, opacity: 0.85),
                Color(.sRGB, white: 1, opacity: 1)
            ),
            (
                "windowSurface", c.windowSurface, Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor)
            ),
            ("dropTarget", c.dropTarget, Color.accentColor, Color.accentColor),
            ("progress", c.progress, Color.blue, Color.blue),
            (
                "terminalSurface", c.terminalSurface, Color(.sRGB, white: 0.07, opacity: 1),
                Color(.sRGB, white: 0.99, opacity: 1)
            ),
            ("syntax.keyword", Theme.Colors.Syntax.keyword, rgb(0xFC5FA3), rgb(0xAD3DA4)),
            ("syntax.string", Theme.Colors.Syntax.string, rgb(0xFC6A5D), rgb(0xD12F1B)),
            ("syntax.number", Theme.Colors.Syntax.number, rgb(0xD0BF69), rgb(0x272AD8)),
            ("syntax.comment", Theme.Colors.Syntax.comment, rgb(0x7F8C98), rgb(0x5D6C79)),
            ("syntax.type", Theme.Colors.Syntax.type, rgb(0x5DD8FF), rgb(0x1F7A85)),
            ("syntax.function", Theme.Colors.Syntax.function, rgb(0x67B7A4), rgb(0x2B6A72)),
            ("syntax.constant", Theme.Colors.Syntax.constant, rgb(0xD0A8FF), rgb(0x6C36A9)),
            ("syntax.attribute", Theme.Colors.Syntax.attribute, rgb(0xFD8F3F), rgb(0x78492A)),
            ("syntax.property", Theme.Colors.Syntax.property, rgb(0x6BBCDD), rgb(0x0F68A0)),
            ("syntax.inserted", Theme.Colors.Syntax.inserted, rgb(0x67D97E), rgb(0x1F7F3A)),
            ("syntax.deleted", Theme.Colors.Syntax.deleted, rgb(0xFC6A5D), rgb(0xC0301F))
        ]
        let catalog = ThemeCatalog()
        for variant in ThemeVariant.allCases {
            let resolved = catalog.resolve(id: variant.defaultID, variant: variant)
            let presentation = ThemePresentation(
                dark: variant == .dark ? resolved.palette : .baseline(.dark),
                light: variant == .light ? resolved.palette : .baseline(.light))
            var environment = EnvironmentValues()
            environment.colorScheme = variant == .dark ? .dark : .light
            environment.themePresentation = presentation
            let appearance = NSAppearance(named: variant == .dark ? .darkAqua : .aqua)!
            appearance.performAsCurrentDrawingAppearance {
                for (name, token, dark, light) in tokens {
                    let expected = variant == .dark ? dark : light
                    check(
                        "\(variant.rawValue) \(name) matches shipped RGBA",
                        bytes(token, in: environment) == bytes(expected, in: environment))
                }
            }
        }
    }

    static func rendering() {
        let c = Theme.Colors.self
        let accent = ThemeColor(rgb: 0xFFCC00)
        let accentForeground = ThemeColor(rgb: 0x102030)
        let ink = ThemeColor(rgb: 0x4FAFD7)
        let muted = ThemeColor(rgb: 0x556677, alpha: 0.7)
        let placeholder = ThemeColor(rgb: 0x667788, alpha: 0.5)
        let border = ThemeColor(rgb: 0x334455, alpha: 0.8)
        let background = ThemeColor(rgb: 0x102030, alpha: 0.62)
        let raised = ThemeColor(rgb: 0x203040)
        let menu = ThemeColor(rgb: 0x304050, alpha: 0.8)
        let selection = ThemeColor(rgb: 0x112244, alpha: 0.4)
        let red = ThemeColor(rgb: 0xC02038)
        let yellow = ThemeColor(rgb: 0xF8D12F)
        let purple = ThemeColor(rgb: 0xBA88DA)
        let custom = ThemePalette(
            variant: .dark, isBaseline: false,
            overrides: [
                .foreground: ink, .background: background, .secondaryBackground: raised, .menuBackground: menu,
                .accent: accent, .accentForeground: accentForeground, .selection: selection,
                .muted: muted, .placeholder: placeholder, .border: border, .red: red, .yellow: yellow,
                .syntaxKeyword: purple
            ])
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        let next = ThemePresentation(dark: custom)
        environment.themePresentation = next
        let semanticColors: [(String, Color, ThemeColor)] = [
            ("ink supplies ramp RGB", c.rowHover, ink.withAlpha(0.05)),
            ("selection supplies the selection fill", c.selection, selection),
            ("muted supplies secondary text", c.textSecondary, muted),
            ("placeholder supplies tertiary text", c.textTertiary, placeholder),
            ("border supplies separators", c.separator, border),
            ("accent supplies the primary action", c.primaryAction, accent),
            ("accent foreground supplies contrasting ink", c.accentInk, accentForeground),
            ("accent foreground supplies the send glyph", c.composerSendInk, accentForeground),
            ("background keeps its alpha", c.panelScrim, background),
            ("secondary background supplies the terminal surface", c.terminalSurface, raised),
            ("menu background keeps its alpha", c.menuBackground, menu),
            ("red supplies the destructive fallback", c.destructive, red),
            ("yellow takes precedence over accent in find marks", c.findCurrent, yellow.withAlpha(0.92)),
            ("syntax keyword takes precedence over accent", Theme.Colors.Syntax.keyword, purple),
            ("syntax deletion falls back to red", Theme.Colors.Syntax.deleted, red)
        ]
        for (label, token, expected) in semanticColors {
            check(label, bytes(token, in: environment) == bytes(expected.swiftUI, in: environment))
        }
        environment.themePresentation.windowOpacity = 0
        check("zero overrides theme alpha", bytes(c.panelScrim, in: environment).last == 0)
        check("zero overrides explicit menu alpha", bytes(c.menuBackground, in: environment).last == 0)
        environment.themePresentation.windowOpacity = 1
        check("one overrides theme alpha", bytes(c.panelScrim, in: environment).last == 255)
        environment.themePresentation = ThemePresentation(windowOpacity: 0.25)
        check("default menu reads an explicit opacity with blur on", bytes(c.menuBackground, in: environment).last == 64)
        environment.themePresentation.windowBlur = false
        check("opacity override applies to default", bytes(c.panelScrim, in: environment).last == 64)
        check(
            "default menu supplies a scrim when blur is off",
            bytes(c.menuBackground, in: environment).last == 64)
        environment.themePresentation = ThemePresentation(dark: custom)
        environment.colorScheme = .light
        check(
            "custom dark leaves light on the default", bytes(c.textPrimary, in: environment) == [0, 0, 0, 255]
        )

        let invalidated = Mutex(false)
        withObservationTracking {
            _ = ThemeRendering.shared.presentation
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        let native = ThemeRendering.appKitColor(c.textPrimary)
        ThemeRendering.shared.apply(next)
        check("a changed snapshot invalidates an observing host", invalidated.withLock { $0 })
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            let resolved = native.usingColorSpace(.sRGB)
            check(
                "AppKit provider reads the latest snapshot", resolved.map { bytes($0) } == [79, 175, 215, 255]
            )
        }
        ThemeRendering.shared.apply(ThemePresentation())
    }

    static func hostedForeground() {
        let color = ThemeColor(rgb: 0xE47820)
        let custom = ThemePalette(variant: .dark, isBaseline: false, overrides: [.foreground: color])
        let swatches = HStack(spacing: 0) {
            Rectangle().fill(.primary)
            Rectangle().fill(.secondary)
            Rectangle().fill(Theme.Colors.textPrimary)
            Rectangle().fill(color.swiftUI)
            Rectangle().fill(.tertiary)
        }
        .frame(width: 50, height: 10)
        func pixel(_ image: NSBitmapImageRep?, x: Int) -> [Int]? {
            image?.colorAt(x: x, y: 5)?.usingColorSpace(.sRGB).map { bytes($0) }
        }
        for scheme in [ColorScheme.dark, .light] {
            let scoped = ImageRenderer(content: swatches.themeScope().environment(\.colorScheme, scheme))
            let plain = ImageRenderer(content: swatches.environment(\.colorScheme, scheme))
            let scopedImage = scoped.cgImage.map(NSBitmapImageRep.init(cgImage:))
            let plainImage = plain.cgImage.map(NSBitmapImageRep.init(cgImage:))
            check("\(scheme) baseline scope preserves native hierarchical foreground",
                [5, 15, 45].allSatisfy { x in
                    let native = pixel(plainImage, x: x)
                    return native != nil && pixel(scopedImage, x: x) == native
                })
        }

        let renderer = ImageRenderer(content: swatches.themeScope().environment(\.colorScheme, .dark))
        let before = renderer.cgImage.map(NSBitmapImageRep.init(cgImage:))
        ThemeRendering.shared.apply(ThemePresentation(dark: custom))
        let deadline = Date(timeIntervalSinceNow: 1)
        var after = renderer.cgImage.map(NSBitmapImageRep.init(cgImage:))
        while pixel(after, x: 5) == pixel(before, x: 5), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            after = renderer.cgImage.map(NSBitmapImageRep.init(cgImage:))
        }
        ThemeRendering.shared.apply(ThemePresentation())

        let primary = pixel(after, x: 5)
        let secondary = pixel(after, x: 15)
        let token = pixel(after, x: 25)
        let reference = pixel(after, x: 35)
        check(
            "the same renderer refreshes its scoped primary style",
            primary != nil && primary == reference && primary != pixel(before, x: 5))
        check("a cached colour token resolves in the updated environment", token != nil && token == reference)
        check(
            "the secondary style keeps the custom hue at a lower opacity",
            (secondary?[0] ?? 0) > (secondary?[1] ?? 0) && (secondary?[1] ?? 0) > (secondary?[2] ?? 0)
                && (secondary?.last ?? 255) < (primary?.last ?? 0))
    }

    static func rgb(_ value: UInt32) -> Color { ThemeColor(rgb: value).swiftUI }

    static func bytes(_ color: Color, in environment: EnvironmentValues) -> [Int] {
        bytes(NSColor(Color(color.resolve(in: environment))).usingColorSpace(.sRGB)!)
    }

    static func bytes(_ color: NSColor) -> [Int] {
        [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
            .map { Int(($0 * 255).rounded()) }
    }
}
