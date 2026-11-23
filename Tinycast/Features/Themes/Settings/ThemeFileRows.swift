import SwiftUI

struct ThemeFileRows: View {
    private struct Creation: Equatable {
        let variant: ThemeVariant
        let selectedID: String
    }

    @Environment(ThemeStore.self) private var themes
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var creation: Creation?
    @State private var creationError: String?
    @State private var showIssues = true

    var body: some View {
        LabeledContent {
            Button("Open") { AppLauncher.open(AppPaths.themesFolder()) }
                .settingsEnabled(themes.hasThemeFolder)
        } label: {
            SettingsRowTitle(.generalAppearance, "Themes folder")
        }
        LabeledContent {
            Button("Create", action: requestCreation)
                .settingsEnabled(creation == nil)
        } label: {
            SettingsRowTitle(.generalAppearance, "Create theme file")
        }
        .task(id: creation) {
            if let request = creation { await create(request) }
        }
        .onDisappear { creation = nil }
        .alert(
            "Couldn't create theme file",
            isPresented: Binding(
                get: { creationError != nil },
                set: { if !$0 { creationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(creationError ?? "")
        }

        let issues = themes.fileIssues
        if !issues.isEmpty {
            DisclosureGroup("Theme file issues", isExpanded: $showIssues) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                            Text(verbatim: issue.message)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                }
                .frame(maxHeight: 150)
            }
        }
    }

    private func requestCreation() {
        let variant: ThemeVariant
        switch settings.appearance {
        case .system: variant = colorScheme == .dark ? .dark : .light
        case .dark: variant = .dark
        case .light: variant = .light
        }
        let selectedID = variant == .dark ? settings.darkTheme : settings.lightTheme
        creation = Creation(variant: variant, selectedID: selectedID)
    }

    private func create(_ request: Creation) async {
        do {
            let url = try await ThemeFileRepository.createStarter(
                in: AppPaths.themesFolder(), variant: request.variant, selectedID: request.selectedID,
                name: String(localized: "My Theme"))
            guard !Task.isCancelled, creation == request else { return }
            creation = nil
            AppLauncher.showInFinder(url)
        } catch {
            guard !Task.isCancelled, creation == request else { return }
            creation = nil
            switch error {
            case ThemeFileRepository.CreationError.folderLimit:
                creationError = String(localized: "Remove a theme file to make room for a new one.")
            default:
                creationError = String(localized: "Check that Tinycast can write to the themes folder.")
            }
        }
    }
}
