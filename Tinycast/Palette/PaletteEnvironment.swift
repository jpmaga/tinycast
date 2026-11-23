import SwiftUI

/// A stored environment value would freeze at panel-build time; a body re-reads under Observation.
private struct InterfaceMetricsScope: ViewModifier {
    let settings: AppSettings
    let fixedScale: CGFloat?

    func body(content: Content) -> some View {
        let metrics = fixedScale.map { settings.interfaceMetrics(at: $0) } ?? settings.interfaceMetrics
        return content.environment(\.metrics, metrics)
    }
}

extension View {
    func interfaceMetrics(_ settings: AppSettings, fixedScale: CGFloat? = nil) -> some View {
        modifier(InterfaceMetricsScope(settings: settings, fixedScale: fixedScale))
    }

    /// Shared, so the ⌘K menu's own hosted hierarchy cannot drift from the palette's.
    func paletteEnvironment(_ core: AppCore) -> some View {
        self
            .interfaceMetrics(core.settings)
            .environment(core)
            .environment(core.settings)
            .environment(core.palette)
            .environment(core.appIndex)
            .environment(core.clipboardStore)
            .environment(core.favorites)
            .environment(core.visibility)
            .environment(core.aliases)
            .environment(core.fallbacks)
            .environment(core.calcHistory)
            .environment(core.currencyRates)
            .environment(core.emojiIndex)
            .environment(core.frequentEmoji)
            .environment(core.fileSearch)
            .environment(core.dictionary)
            .environment(core.menuSearch)
            .environment(core.windowSwitch)
            .environment(core.runningApps)
            .environment(core.hotKeys)
            .environment(core.uninstall)
            .environment(core.quicklinks)
            .environment(core.snippetsStore)
            .environment(core.extensions)
            .environment(core.calendarStore)
            .environment(core.meetingClock)
            .environment(core.updateCoordinator)
            .motionScope()
    }
}
