import AppKit

extension ClipDragPayload {
    /// The row tile is already cached at this size, so the preview costs no decode.
    private static let previewPixel: CGFloat = 64

    /// A link writes two types from one item, so the receiver takes whichever it reads.
    @MainActor
    func dragItem(metrics: InterfaceMetrics) -> RowDragItem {
        switch self {
        case .file(let url):
            let tile =
                ImageThumbnail.cached(url, maxPixel: Self.previewPixel)
                ?? FilePreviewThumbnail.cached(url, maxPixel: Self.previewPixel)
            return .file(url, image: tile)
        case .link(let url, let text):
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .URL)
            item.setString(text, forType: .string)
            return RowDragItem(writer: item, image: Self.textImage(text, metrics: metrics))
        case .text(let text):
            return RowDragItem(writer: text as NSString, image: Self.textImage(text, metrics: metrics))
        }
    }

    /// Drawn, not snapshotted: SwiftUI draws into layers, so `cacheDisplay` returns a clear bitmap.
    @MainActor
    private static func textImage(_ copy: String, metrics: InterfaceMetrics) -> NSImage {
        let system = NSFont.systemFont(ofSize: metrics.scaled(12))
        let font = InterfaceFont.resolve(metrics.fontFamily, matching: system) ?? system
        let radius = metrics.radius.thumbnail
        let line = copy.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let string = NSAttributedString(
            string: String(line.prefix(60)),
            attributes: [
                .font: font, .foregroundColor: ThemeRendering.appKitColor(Theme.Colors.dragPreviewInk)
            ])
        let inset = NSSize(width: 10, height: 6)
        let text = string.size()
        let size = NSSize(
            width: min(text.width, 320) + inset.width * 2, height: text.height + inset.height * 2)
        return NSImage(size: size, flipped: false) { rect in
            ThemeRendering.appKitColor(Theme.Colors.dragPreviewSurface).withAlphaComponent(0.95).setFill()
            NSBezierPath(
                roundedRect: rect, xRadius: radius, yRadius: radius
            ).fill()
            string.draw(
                in: NSRect(
                    x: inset.width, y: inset.height, width: rect.width - inset.width * 2,
                    height: text.height))
            return true
        }
    }
}
