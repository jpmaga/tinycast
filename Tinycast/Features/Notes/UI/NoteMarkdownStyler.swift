import AppKit
import SwiftUI

/// Turns a parsed line into attributes; bullets keep their dot even when the caret reveals syntax.
@MainActor
struct NoteMarkdownStyler {
    let typography: NoteMarkdownTypography
    private let radius: InterfaceMetrics.Radius
    let literal: Attributes

    init(metrics: InterfaceMetrics) {
        typography = metrics == .standard ? .standard : NoteMarkdownTypography(metrics: metrics)
        radius = metrics.radius
        literal = [.font: typography.body, .foregroundColor: Self.noteInk]
    }

    /// One instance, so every styler's literal compares equal and shares the theme bridge.
    static let noteInk = ThemeRendering.appKitColor(Theme.Colors.noteText)

    typealias Attributes = [NSAttributedString.Key: Any]

    struct LineStyle {
        /// Set over the whole line, replacing whatever it carried.
        let base: Attributes
        /// Added on top of `base`, in order, so inner spans override outer ones.
        let runs: [(range: NSRange, attributes: Attributes)]
    }

    private static let hidden: Attributes = [
        .font: NoteMarkdownTypography.hidden,
        .foregroundColor: NSColor.clear
    ]
    private var hiddenEmptyListMarker: Attributes {
        [.font: typography.body, .foregroundColor: NSColor.clear]
    }

    private var listSlot: CGFloat {
        NoteCheckboxGeometry.slot(bodyPointSize: typography.body.pointSize)
    }
    private static let quoteStep = Theme.Size.markdownQuoteBar + Theme.Spacing.lg
    private static let codeInset = Theme.Spacing.lg
    /// Space after each list item, kept when revealed so moving the caret never shifts the rows.
    private static let listItemSpacing = Theme.Spacing.md
    /// Only these get a `.link` attribute, and only these are opened when one is clicked.
    static let openableSchemes: Set<String> = ["http", "https", "mailto"]

    /// Colours the fragment draws with are resolved now, under the caller's drawing appearance.
    func style(
        at index: Int, in markdown: NoteMarkdown, text: NSString, isRevealed: Bool
    ) -> LineStyle {
        let line = markdown.lines[index]
        var base = literal
        var runs: [(range: NSRange, attributes: Attributes)] = []
        let markerLook = isRevealed ? Self.revealedMarker : Self.hidden

        switch line.kind {
        case .blank, .paragraph:
            break
        case .heading(let level):
            base[.font] = typography.heading(level)
            base[.paragraphStyle] = Self.paragraph {
                $0.paragraphSpacingBefore =
                    index == 0 ? 0 : level <= 2 ? Theme.Spacing.xl : Theme.Spacing.md
                $0.paragraphSpacing = Theme.Spacing.xs
            }
            if let marker = line.markerRange { runs.append((marker, markerLook)) }
        case .bullet, .ordered, .task:
            let revealsMarker = !NoteRevealPolicy.hidesMarker(of: line, isRevealed: isRevealed)
            let isEmpty = line.contentRange.length == 0
            if let marker = line.markerRange {
                let listMarkerLook: Attributes =
                    revealsMarker
                    ? [.foregroundColor: Self.color(Theme.Colors.textSecondary)]
                    : (isEmpty ? hiddenEmptyListMarker : Self.hidden)
                runs.append((marker, listMarkerLook))
            }
            if case .task(checked: true) = line.kind {
                runs.append((line.contentRange, Self.checkedTask))
            }
            let contentIndent = CGFloat(line.level + 1) * listSlot
            base[.paragraphStyle] =
                revealsMarker || isEmpty
                ? hanging(
                    line.markerRange, in: text, contentIndent: contentIndent, spacingAfter: Self.listItemSpacing)
                : Self.indented(by: contentIndent, spacingAfter: Self.listItemSpacing)
            if !revealsMarker { base[.noteBlockDecoration] = listDecoration(line, text: text) }
        case .quote(let depth):
            if let marker = line.markerRange { runs.append((marker, markerLook)) }
            runs.append((line.contentRange, [.foregroundColor: Self.color(Theme.Colors.textSecondary)]))
            guard !isRevealed else {
                base[.paragraphStyle] = hanging(
                    line.markerRange, in: text, contentIndent: CGFloat(depth) * Self.quoteStep)
                break
            }
            base[.paragraphStyle] = Self.indented(by: CGFloat(depth) * Self.quoteStep)
            base[.noteBlockDecoration] = decoration(
                .quote(depth: depth), fill: Theme.Colors.border, ink: Theme.Colors.border)
        case .rule:
            guard !isRevealed else {
                base[.foregroundColor] = Self.color(Theme.Colors.textTertiary)
                break
            }
            base[.foregroundColor] = NSColor.clear
            base[.noteBlockDecoration] = decoration(
                .rule, fill: Theme.Colors.separator, ink: Theme.Colors.separator)
        case .table:
            base[.font] = typography.codeBlock
            base[.paragraphStyle] = Self.tableRow
        case .fenceOpen, .fenceClose, .code:
            base[.font] = typography.codeBlock
            base[.paragraphStyle] = Self.codeParagraph
            if line.kind != .code {
                base[.foregroundColor] = isRevealed ? Self.color(Theme.Colors.textTertiary) : NSColor.clear
            }
            base[.noteBlockDecoration] = decoration(
                .code(Self.codeRow(index, markdown), language: Self.language(line.kind)),
                fill: Theme.Colors.cardFill, ink: Theme.Colors.textTertiary)
        }

        let lineFont = base[.font] as? NSFont ?? typography.body
        runs += inlineRuns(markdown.inlines(of: line), lineFont: lineFont, text: text, isRevealed: isRevealed)
        return LineStyle(base: base, runs: runs)
    }

    // MARK: - Inlines

    private func inlineRuns(
        _ inlines: [NoteMarkdown.Inline], lineFont: NSFont, text: NSString, isRevealed: Bool
    ) -> [(range: NSRange, attributes: Attributes)] {
        var runs: [(range: NSRange, attributes: Attributes)] = []
        for (position, inline) in inlines.enumerated() {
            let font = Self.spanFont(inlines[...position], lineFont: lineFont)
            var markerLook = isRevealed ? Self.revealedMarker.merging([.font: font]) { $1 } : Self.hidden
            switch inline.kind {
            case .strong, .emphasis, .strongEmphasis:
                runs.append((inline.contentRange, [.font: font]))
            case .strikethrough:
                runs.append((inline.contentRange, [.strikethroughStyle: NSUnderlineStyle.single.rawValue]))
            case .code:
                let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
                if isRevealed { markerLook[.font] = codeFont }
                let background = Self.color(Theme.Colors.controlSurface)
                runs.append((inline.contentRange, [.font: codeFont, .backgroundColor: background]))
            case .link(let destination):
                runs.append((inline.contentRange, Self.linkLook(URL(string: destination), isRevealed: isRevealed)))
            case .autolink:
                let url = URL(string: text.substring(with: inline.range))
                runs.append((inline.range, Self.linkLook(url, isRevealed: isRevealed)))
            }
            runs += inline.markerRanges.map { ($0, markerLook) }
        }
        return runs
    }

    /// The span's font: the line font plus the traits of every emphasis span enclosing it.
    private static func spanFont(_ spans: ArraySlice<NoteMarkdown.Inline>, lineFont: NSFont) -> NSFont {
        guard let span = spans.last else { return lineFont }
        var traits: NSFontDescriptor.SymbolicTraits = []
        for outer in spans where NSIntersectionRange(outer.range, span.range) == span.range {
            switch outer.kind {
            case .strong: traits.insert(.bold)
            case .emphasis: traits.insert(.italic)
            case .strongEmphasis: traits.formUnion([.bold, .italic])
            default: break
            }
        }
        return traits.isEmpty ? lineFont : NoteMarkdownTypography.adding(traits, to: lineFont)
    }

    /// A revealed link is plain coloured text, so a click places the caret to edit its URL.
    private static func linkLook(_ url: URL?, isRevealed: Bool) -> Attributes {
        guard !isRevealed else { return [.foregroundColor: ThemeRendering.appKitColor(Theme.Colors.linkInk)] }
        guard let url, let scheme = url.scheme?.lowercased(), openableSchemes.contains(scheme) else {
            return [:]
        }
        return [.link: url]
    }

    // MARK: - Blocks

    private static var revealedMarker: Attributes {
        [.foregroundColor: color(Theme.Colors.textTertiary)]
    }

    private static var checkedTask: Attributes {
        [
            .foregroundColor: color(Theme.Colors.textSecondary),
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    /// A wrapped table row hangs under its first line, so each row still reads as one.
    private static let tableRow: NSParagraphStyle = paragraph { $0.headIndent = Theme.Spacing.lg }

    private static let codeParagraph: NSParagraphStyle = paragraph {
        $0.firstLineHeadIndent = codeInset
        $0.headIndent = codeInset
        $0.tailIndent = -codeInset
    }

    private static func indented(by indent: CGFloat, spacingAfter: CGFloat = 0) -> NSParagraphStyle {
        paragraph {
            $0.firstLineHeadIndent = indent
            $0.headIndent = indent
            $0.paragraphSpacing = spacingAfter
        }
    }

    /// A revealed marker hangs left of the content, so text stays where the rendered line had it.
    private func hanging(
        _ marker: NSRange?, in text: NSString, contentIndent: CGFloat, spacingAfter: CGFloat = 0
    ) -> NSParagraphStyle {
        let markerText = marker.map { text.substring(with: $0) as NSString }
        let width = markerText?.size(withAttributes: [.font: typography.body]).width ?? 0
        return Self.paragraph {
            $0.firstLineHeadIndent = max(0, contentIndent - width)
            $0.headIndent = contentIndent
            $0.paragraphSpacing = spacingAfter
        }
    }

    private static func paragraph(_ configure: (NSMutableParagraphStyle) -> Void) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        configure(style)
        return style
    }

    private func listDecoration(_ line: NoteMarkdown.Line, text: NSString) -> NoteBlockDecoration {
        let shape: NoteBlockDecoration.Shape
        switch line.kind {
        case .task(let checked):
            shape = .task(level: line.level, checked: checked)
        case .ordered:
            let label = text.substring(with: line.markerRange ?? line.contentRange)
                .trimmingCharacters(in: .whitespaces)
            shape = .ordered(level: line.level, label: label)
        default:
            shape = .bullet(level: line.level)
        }
        return decoration(shape, fill: Theme.Colors.textSecondary, ink: Theme.Colors.textSecondary)
    }

    private static func codeRow(_ index: Int, _ markdown: NoteMarkdown) -> NoteBlockDecoration.Shape.CodeRow {
        let blocks = markdown.fenceBlocks
        var low = 0
        var high = blocks.count
        while low < high {
            let middle = (low + high) / 2
            if blocks[middle].upperBound < index { low = middle + 1 } else { high = middle }
        }
        guard low < blocks.count, blocks[low].contains(index) else { return .middle }
        let block = blocks[low]
        switch index {
        case block.lowerBound where block.lowerBound == block.upperBound: return .single
        case block.lowerBound: return .top
        case block.upperBound: return .bottom
        default: return .middle
        }
    }

    private static func language(_ kind: NoteMarkdown.Line.Kind) -> String? {
        guard case .fenceOpen(let language) = kind else { return nil }
        return language
    }

    private func decoration(
        _ shape: NoteBlockDecoration.Shape, fill: Color, ink: Color
    ) -> NoteBlockDecoration {
        let standard = NoteMarkdownTypography.standard
        return NoteBlockDecoration(
            shape: shape, fill: Self.color(fill), ink: Self.color(ink),
            bodyPointSize: typography.body.pointSize,
            bodyFontName: typography.body == standard.body ? nil : typography.body.fontName,
            captionFontName: typography.caption == standard.caption ? nil : typography.caption.fontName,
            radius: radius)
    }

    /// Pins a dynamic token to the current drawing appearance; the fragment cannot resolve one.
    private static func color(_ token: Color) -> NSColor {
        if let resolved = resolved[token] { return resolved }
        let color = ThemeRendering.appKitColor(token)
        let pinned = NSColor(cgColor: color.cgColor) ?? color
        resolved[token] = pinned
        return pinned
    }

    /// Pinned colours belong to one appearance, so a change to it has to drop them.
    static func invalidateColors() {
        resolved.removeAll(keepingCapacity: true)
    }

    private static var resolved: [Color: NSColor] = [:]
}
