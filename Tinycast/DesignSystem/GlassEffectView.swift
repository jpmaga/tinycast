import SwiftUI

struct GlassEffectView: View {
    @Environment(\.themePresentation) private var presentation

    var body: some View {
        if presentation.windowBlur { GlassBackground() }
    }

    private struct GlassBackground: NSViewRepresentable {
        func makeNSView(context: Context) -> NSGlassEffectView {
            NSGlassEffectView()
        }

        func updateNSView(_ nsView: NSGlassEffectView, context: Context) {}
    }
}
