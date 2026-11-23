import SwiftUI

struct InterfaceMetrics: Equatable, Sendable {
    static let standard = InterfaceMetrics()

    var scale: CGFloat = 1
    var fontFamily = InterfaceFont.system
    var cornerMultiplier: CGFloat = 1

    var spacing: Spacing { Spacing(scale: scale) }
    var radius: Radius { Radius(scale: scale, multiplier: cornerMultiplier) }
    var size: Size { Size(scale: scale) }
    var typography: Typography { Typography(scale: scale, fontFamily: fontFamily) }

    /// For a tuned length a surface owns itself, where `Theme` states no token for it.
    func scaled(_ value: CGFloat) -> CGFloat { scaledPoints(value, scale) }

    struct Spacing: Equatable, Sendable {
        let scale: CGFloat

        var xxs: CGFloat { scaledPoints(Theme.Spacing.xxs, scale) }
        var xs: CGFloat { scaledPoints(Theme.Spacing.xs, scale) }
        var sm: CGFloat { scaledPoints(Theme.Spacing.sm, scale) }
        var md: CGFloat { scaledPoints(Theme.Spacing.md, scale) }
        var lg: CGFloat { scaledPoints(Theme.Spacing.lg, scale) }
        var xl: CGFloat { scaledPoints(Theme.Spacing.xl, scale) }
        var dialogInset: CGFloat { scaledPoints(Theme.Spacing.dialogInset, scale) }
        var xxl: CGFloat { scaledPoints(Theme.Spacing.xxl, scale) }
        var xxxl: CGFloat { scaledPoints(Theme.Spacing.xxxl, scale) }
        var sectionHeaderBottom: CGFloat { scaledPoints(Theme.Spacing.sectionHeaderBottom, scale) }
        var sectionSpacing: CGFloat { scaledPoints(Theme.Spacing.sectionSpacing, scale) }
        var emojiSectionSpacing: CGFloat { scaledPoints(Theme.Spacing.emojiSectionSpacing, scale) }
        var chatTranscriptBottom: CGFloat { scaledPoints(Theme.Spacing.chatTranscriptBottom, scale) }
        var chatFollowTailSlack: CGFloat { scaledPoints(Theme.Spacing.chatFollowTailSlack, scale) }
        var chatLine: CGFloat { scaledPoints(Theme.Spacing.chatLine, scale) }
    }

    struct Radius: Hashable, Sendable {
        let scale: CGFloat
        let multiplier: CGFloat

        var panel: CGFloat { scaled(Theme.Radius.panel) }
        var row: CGFloat { scaled(Theme.Radius.row) }
        var formField: CGFloat { scaled(Theme.Radius.formField) }
        var emojiCell: CGFloat { scaled(Theme.Radius.emojiCell) }
        var menu: CGFloat { scaled(Theme.Radius.menu) }
        var menuRow: CGFloat { menuRow(inset: Spacing(scale: scale).sm) }

        func menuRow(inset: CGFloat) -> CGFloat {
            multiplier == 1 ? scaled(Theme.Radius.menuRow) : max(0, menuPanel - inset)
        }
        var barControl: CGFloat { scaled(Theme.Radius.barControl) }
        var menuPanel: CGFloat { scaled(Theme.Radius.menuPanel) }
        var dialogSymbol: CGFloat { scaled(Theme.Radius.dialogSymbol) }
        var dialog: CGFloat { scaled(Theme.Radius.dialog) }
        var thumbnail: CGFloat { scaled(Theme.Radius.thumbnail) }
        var glyph: CGFloat { scaled(Theme.Radius.glyph) }
        var attachmentChip: CGFloat { scaled(Theme.Radius.attachmentChip) }
        var card: CGFloat { scaled(Theme.Radius.card) }
        var codeBlock: CGFloat { scaled(Theme.Radius.codeBlock) }
        var keyCap: CGFloat { scaled(Theme.Radius.keyCap) }
        var tooltip: CGFloat { scaled(Theme.Radius.tooltip) }

        var hasSquareCorners: Bool { multiplier == 0 }
        func capsuleRadius(diameter: CGFloat) -> CGFloat { hasSquareCorners ? 0 : diameter / 2 }
        var capsule: AnyShape { hasSquareCorners ? AnyShape(Rectangle()) : AnyShape(Capsule()) }
        var circle: AnyShape { hasSquareCorners ? AnyShape(Rectangle()) : AnyShape(Circle()) }

        func scaled(_ value: CGFloat) -> CGFloat { scaledPoints(value, scale * multiplier) }
    }

    struct Size: Equatable, Sendable {
        let scale: CGFloat

        var panelWidth: CGFloat { scaledPoints(Theme.Size.panelWidth, scale) }
        var panelHeight: CGFloat { scaledPoints(Theme.Size.panelHeight, scale) }
        var headerHeight: CGFloat { scaledPoints(Theme.Size.headerHeight, scale) }
        var headerIconSlot: CGFloat { scaledPoints(Theme.Size.headerIconSlot, scale) }
        var searchFieldMinWidth: CGFloat { scaledPoints(Theme.Size.searchFieldMinWidth, scale) }
        var headerPadding: CGFloat { scaledPoints(Theme.Size.headerPadding, scale) }
        /// Derived, not scaled: the compact bar must stay exactly the header in symmetric slack.
        var compactHeight: CGFloat { headerHeight + headerPadding * 2 }
        var bottomBarHeight: CGFloat { scaledPoints(Theme.Size.bottomBarHeight, scale) }
        var textAreaUnit: CGFloat { scaledPoints(Theme.Size.textAreaUnit, scale) }
        var barButtonHeight: CGFloat { scaledPoints(Theme.Size.barButtonHeight, scale) }
        var rowIcon: CGFloat { scaledPoints(Theme.Size.rowIcon, scale) }
        var resultRowIcon: CGFloat { scaledPoints(Theme.Size.resultRowIcon, scale) }
        var colorDot: CGFloat { scaledPoints(Theme.Size.colorDot, scale) }
        var calendarBarWidth: CGFloat { scaledPoints(Theme.Size.calendarBarWidth, scale) }
        var calendarBarHeight: CGFloat { scaledPoints(Theme.Size.calendarBarHeight, scale) }
        var keyCap: CGFloat { scaledPoints(Theme.Size.keyCap, scale) }
        var compactKeyCap: CGFloat { scaledPoints(Theme.Size.compactKeyCap, scale) }
        var heroKeyCap: CGFloat { scaledPoints(Theme.Size.heroKeyCap, scale) }
        var menuButton: CGFloat { scaledPoints(Theme.Size.menuButton, scale) }
        var checkbox: CGFloat { scaledPoints(Theme.Size.checkbox, scale) }

        var menuWidth: CGFloat { scaledPoints(Theme.Size.menuWidth, scale) }
        var formMenuMinimumWidth: CGFloat { scaledPoints(Theme.Size.formMenuMinimumWidth, scale) }
        var formMenuExtraRowsHeight: CGFloat { scaledPoints(Theme.Size.formMenuExtraRowsHeight, scale) }
        var formFieldFocusStroke: CGFloat { scaledPoints(Theme.Size.formFieldFocusStroke, scale) }
        var actionMenuWidth: CGFloat { scaledPoints(Theme.Size.actionMenuWidth, scale) }
        var clipboardFilterMenuWidth: CGFloat { scaledPoints(Theme.Size.clipboardFilterMenuWidth, scale) }
        var fileSearchFilterMenuWidth: CGFloat { scaledPoints(Theme.Size.fileSearchFilterMenuWidth, scale) }
        var emojiCategoryMenuWidth: CGFloat { scaledPoints(Theme.Size.emojiCategoryMenuWidth, scale) }
        var menuIcon: CGFloat { scaledPoints(Theme.Size.menuIcon, scale) }
        var menuBrandIcon: CGFloat { scaledPoints(Theme.Size.menuBrandIcon, scale) }
        var barBrandIcon: CGFloat { scaledPoints(Theme.Size.barBrandIcon, scale) }
        var menuRowSpacing: CGFloat { scaledPoints(Theme.Size.menuRowSpacing, scale) }
        var menuSectionHeader: CGFloat { scaledPoints(Theme.Size.menuSectionHeader, scale) }
        /// Derived like `Theme`'s, so the row cap still counts whole rows at every size.
        var menuRowHeight: CGFloat { menuIcon + Spacing(scale: scale).md * 2 }
        var menuRowsMaxHeight: CGFloat {
            (Theme.Size.menuVisibleRows * (menuRowHeight + menuRowSpacing)).rounded()
        }
        var clipboardListWidth: CGFloat { scaledPoints(Theme.Size.clipboardListWidth, scale) }
        var clipboardMediaHeight: CGFloat { scaledPoints(Theme.Size.clipboardMediaHeight, scale) }
        var clipboardPreviewPixel: CGFloat { scaledPoints(Theme.Size.clipboardPreviewPixel, scale) }
        var emojiGridInset: CGFloat { scaledPoints(Theme.Size.emojiGridInset, scale) }
        var emojiCell: CGFloat { scaledPoints(Theme.Size.emojiCell, scale) }

        var markdownListMarker: CGFloat { scaledPoints(Theme.Size.markdownListMarker, scale) }
        var markdownQuoteBar: CGFloat { scaledPoints(Theme.Size.markdownQuoteBar, scale) }
        var chatMessageAction: CGFloat { scaledPoints(Theme.Size.chatMessageAction, scale) }
        var chatSourceBadge: CGFloat { scaledPoints(Theme.Size.chatSourceBadge, scale) }
        var chatJumpToLatest: CGFloat { scaledPoints(Theme.Size.chatJumpToLatest, scale) }
        var chatImageThumb: CGFloat { scaledPoints(Theme.Size.chatImageThumb, scale) }
        var chatAttachmentGlyph: CGFloat { scaledPoints(Theme.Size.chatAttachmentGlyph, scale) }
        var chatAttachmentThumb: CGFloat { scaledPoints(Theme.Size.chatAttachmentThumb, scale) }
        var chatAttachmentRemove: CGFloat { scaledPoints(Theme.Size.chatAttachmentRemove, scale) }
        var chatAttachmentInset: CGFloat { scaledPoints(Theme.Size.chatAttachmentInset, scale) }

        var quickActionPanel: CGFloat { scaledPoints(Theme.Size.quickActionPanel, scale) }
        var quickActionHeaderIcon: CGFloat { scaledPoints(Theme.Size.quickActionHeaderIcon, scale) }
        var quickActionScrollFade: CGFloat { scaledPoints(Theme.Size.quickActionScrollFade, scale) }
        var quickActionPanelBody: CGFloat { scaledPoints(Theme.Size.quickActionPanelBody, scale) }
        var quickActionPanelMinBody: CGFloat { scaledPoints(Theme.Size.quickActionPanelMinBody, scale) }

        var dialogCompactWidth: CGFloat { scaledPoints(Theme.Size.dialogCompactWidth, scale) }
        var dialogWidth: CGFloat { scaledPoints(Theme.Size.dialogWidth, scale) }
        var dialogTextHeight: CGFloat { scaledPoints(Theme.Size.dialogTextHeight, scale) }
        var dialogButtonHeight: CGFloat {
            menuButton
                - scaledPoints(Theme.Size.menuButton - Theme.Size.dialogButtonHeight, scale)
        }
        var dialogSymbol: CGFloat { scaledPoints(Theme.Size.dialogSymbol, scale) }
        var dialogSymbolContainer: CGFloat {
            scaledPoints(Theme.Size.dialogSymbolContainer, scale)
        }
        var dialogIcon: CGFloat { scaledPoints(Theme.Size.dialogIcon, scale) }
        var hudMaxWidth: CGFloat { scaledPoints(Theme.Size.hudMaxWidth, scale) }
        var hudWidth: CGFloat { scaledPoints(Theme.Size.hudWidth, scale) }
        var hudHeight: CGFloat { scaledPoints(Theme.Size.hudHeight, scale) }
        var volumeTrackHeight: CGFloat { scaledPoints(Theme.Size.volumeTrackHeight, scale) }
        var volumeReadout: CGFloat { scaledPoints(Theme.Size.volumeReadout, scale) }
    }

    struct Typography: Sendable {
        let scale: CGFloat
        let fontFamily: String

        var searchFieldSize: CGFloat { scaledPoints(Theme.Typography.searchFieldSize, scale) }
        @MainActor var searchField: Font {
            let fallback = scale == 1 ? Theme.Typography.searchField : Font.system(size: searchFieldSize, weight: .regular)
            return font(fallback, matching: searchFieldSystemFont)
        }

        @MainActor var searchFieldNSFont: NSFont {
            InterfaceFont.resolve(fontFamily, matching: searchFieldSystemFont) ?? searchFieldSystemFont
        }

        @MainActor private var searchFieldSystemFont: NSFont {
            scale == 1
                ? Theme.Typography.searchFieldNSFont
                : NSFont.systemFont(ofSize: searchFieldSize, weight: .regular)
        }

        var headerIcon: Font {
            scale == 1
                ? Theme.Typography.headerIcon
                : .system(size: scaledPoints(Theme.Typography.headerIconSize, scale), weight: .medium)
        }

        @MainActor var rowTitle: Font { font(Theme.Typography.rowTitle, .body) }
        @MainActor var rowTrailing: Font { font(Theme.Typography.rowTrailing, .callout) }
        @MainActor var sectionHeader: Font { font(Theme.Typography.sectionHeader, .subheadline, weight: .medium) }
        @MainActor var panelTitle: Font { font(Theme.Typography.panelTitle, .headline) }
        @MainActor var calcResult: Font { font(Theme.Typography.calcResult, .title1) }
        @MainActor var keyCap: Font { font(Theme.Typography.keyCap, .caption1) }
        @MainActor var compactKeyCap: Font { font(Theme.Typography.compactKeyCap, .caption2) }
        @MainActor var heroKeyCap: Font { font(Theme.Typography.heroKeyCap, .body) }
        @MainActor var markdownHeading1: Font {
            font(Theme.Typography.markdownHeading1, .title2, weight: .semibold)
        }
        @MainActor var markdownHeading2: Font {
            font(Theme.Typography.markdownHeading2, .title3, weight: .semibold)
        }
        @MainActor var markdownHeading3: Font { font(Theme.Typography.markdownHeading3, .headline) }
        var code: Font {
            scale == 1
                ? Theme.Typography.code
                : .system(size: systemFont(.callout).pointSize, design: .monospaced)
        }
        var inlineCode: Font { scale == 1 ? Theme.Typography.inlineCode : Font(systemFont(.body)).monospaced() }
        @MainActor var bar: Font { font(Theme.Typography.bar, .callout, weight: .medium) }
        @MainActor var chip: Font { font(Theme.Typography.chip, .callout) }
        @MainActor var chipNSFont: NSFont {
            if scale == 1, fontFamily == InterfaceFont.system { return Theme.Typography.chipNSFont }
            return textNSFont(.callout)
        }
        @MainActor var disclosure: Font {
            scale == 1 ? Theme.Typography.disclosure : Font(systemFont(.caption1)).weight(.semibold)
        }
        @MainActor var menuRow: Font { font(Theme.Typography.menuRow, .body) }
        @MainActor var menuShortcut: Font { font(Theme.Typography.menuShortcut, .callout) }
        @MainActor var menuIcon: Font { scale == 1 ? Theme.Typography.menuIcon : Font(systemFont(.body)) }

        @MainActor
        func textNSFont(
            _ style: NSFont.TextStyle, weight: NSFont.Weight? = nil, monospaced: Bool = false
        ) -> NSFont {
            let base = systemFont(style)
            if monospaced { return .monospacedSystemFont(ofSize: base.pointSize, weight: weight ?? .regular) }
            let fallback = weight.map { NSFont.systemFont(ofSize: base.pointSize, weight: $0) } ?? base
            guard fontFamily != InterfaceFont.system else { return fallback }
            let reference = matchingFont(for: style, systemFont: base, explicitWeight: weight)
            return InterfaceFont.resolve(fontFamily, matching: reference) ?? fallback
        }

        @MainActor
        func font(_ fallback: Font, _ style: NSFont.TextStyle, weight: NSFont.Weight? = nil) -> Font {
            if scale == 1, fontFamily == InterfaceFont.system { return fallback }
            let system = systemFont(style)
            if fontFamily != InterfaceFont.system {
                let reference = matchingFont(for: style, systemFont: system, explicitWeight: weight)
                if let custom = InterfaceFont.resolve(fontFamily, matching: reference) { return Font(custom) }
            }
            guard scale != 1 else { return fallback }
            return Font(weight.map { NSFont.systemFont(ofSize: system.pointSize, weight: $0) } ?? system)
        }

        @MainActor
        func font(_ fallback: Font, matching systemFont: NSFont) -> Font {
            InterfaceFont.resolve(fontFamily, matching: systemFont).map(Font.init) ?? fallback
        }

        private func matchingFont(
            for style: NSFont.TextStyle, systemFont: NSFont, explicitWeight: NSFont.Weight?
        ) -> NSFont {
            let weight = explicitWeight ?? (style == .caption2 ? .medium : nil)
            return weight.map { NSFont.systemFont(ofSize: systemFont.pointSize, weight: $0) } ?? systemFont
        }

        private func systemFont(_ style: NSFont.TextStyle) -> NSFont {
            let base = NSFont.preferredFont(forTextStyle: style)
            guard scale != 1 else { return base }
            return NSFont(descriptor: base.fontDescriptor, size: scaledPoints(base.pointSize, scale)) ?? base
        }
    }
}

/// Whole points: a fractional row pitch lands keycap edges and the dissolve mask off-pixel.
private func scaledPoints(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
    scale == 1 ? value : (value * scale).rounded()
}

extension EnvironmentValues {
    /// `.standard` by default, so a shared `DesignSystem` view outside the palette never scales.
    @Entry var metrics = InterfaceMetrics.standard
}
