import SwiftUI

struct ThemeAppearanceRows: View {
    @Environment(ThemeStore.self) private var themes
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var settings = settings
        LabeledContent {
            themePicker(.dark, selection: $settings.darkTheme)
        } label: {
            SettingsRowTitle(.generalAppearance, "Dark theme")
        }
        LabeledContent {
            themePicker(.light, selection: $settings.lightTheme)
        } label: {
            SettingsRowTitle(.generalAppearance, "Light theme")
        }
        ThemeFileRows()
        Toggle(
            isOn: Binding(
                get: { settings.windowOpacity == nil },
                set: { settings.windowOpacity = $0 ? nil : defaultOpacity }
            )
        ) {
            SettingsRowTitle(.generalAppearance, "Use theme opacity")
        }
        LabeledContent {
            Slider(
                value: Binding(
                    get: { settings.windowOpacity ?? defaultOpacity },
                    set: { settings.windowOpacity = $0 }
                ), in: 0...1, step: 0.01
            ) {
                Text("Window opacity")
            }
            .labelsHidden()
            .frame(width: 112)
            Text((settings.windowOpacity ?? defaultOpacity).formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } label: {
            SettingsRowTitle(.generalAppearance, "Window opacity")
        }
        .disabled(settings.windowOpacity == nil)
        Toggle(isOn: $settings.windowBlur) {
            SettingsRowTitle(.generalAppearance, "Blur behind windows")
        }
    }

    private var defaultOpacity: Double {
        let dark = colorScheme == .dark
        let id = dark ? settings.darkTheme : settings.lightTheme
        return themes.catalog.resolve(id: id, variant: dark ? .dark : .light).palette.background.alpha
    }

    @ViewBuilder
    private func themePicker(_ variant: ThemeVariant, selection: Binding<String>) -> some View {
        let builtIns = ThemeCatalog.builtIns.filter { $0.variant == variant }
        let userThemes = themes.userDefinitions.filter { $0.variant == variant }
        let displayedID =
            (builtIns + userThemes).contains { $0.id == selection.wrappedValue } ? selection.wrappedValue : variant.defaultID
        let palette = themes.catalog.resolve(id: displayedID, variant: variant).palette
        let swatches = [palette.background.withAlpha(1), palette.foreground, palette.accent].compactMap { $0 }
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color.swiftUI)
                    .overlay { Circle().strokeBorder(Color.primary.opacity(0.20)) }
                    .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
            }
        }
        .accessibilityHidden(true)
        Picker(
            selection: Binding(
                get: { displayedID }, set: { selection.wrappedValue = $0 }
            )
        ) {
            if userThemes.isEmpty {
                themeOptions(builtIns)
            } else {
                Section("Built-in themes") { themeOptions(builtIns) }
                Section("User themes") { themeOptions(userThemes) }
            }
        } label: {
            switch variant {
            case .dark: Text("Dark theme")
            case .light: Text("Light theme")
            }
        }
        .labelsHidden()
    }

    private func themeOptions(_ definitions: [ThemeDefinition]) -> some View {
        ForEach(definitions) { definition in
            Text(verbatim: definition.name).tag(definition.id)
        }
    }
}
