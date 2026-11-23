import AppKit
import SwiftUI

@MainActor
final class MessageHUDController {
    private let presenter: HUDPresenter
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        presenter = HUDPresenter(
            anchor: .edgeInset(Theme.Size.hudEdgeOffset),
            dwell: Theme.Duration.messageHUD,
            screen: { settings.openOnCursorScreen ? .underCursor : .primary })
    }

    func show(message: String, tone: DialogTone = .success) {
        presenter.show(
            content(MessageHUDView(message: message, accessory: .tone(tone))))
    }

    /// Stays up until the work it reports ends and something replaces it, or `dismiss()` runs.
    func showProgress(message: String, onCancel: (() -> Void)? = nil) {
        presenter.show(
            content(MessageHUDView(message: message, accessory: .progress, onCancel: onCancel)),
            dwells: false,
            interactive: onCancel != nil)
    }

    func dismiss() {
        presenter.dismiss()
    }

    private func content(_ view: MessageHUDView) -> some View {
        view.interfaceMetrics(settings, fixedScale: settings.interfaceSize.scale)
            .onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in
                self?.presenter.resize(to: size)
            }
    }
}
