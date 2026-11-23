import Observation
import OSLog

@MainActor
@Observable
final class ThemeStore {
    private static let logger = Logger(subsystem: "com.tinycast", category: "Themes")

    private let appliesThemes: Bool
    private var darkID = ThemeVariant.dark.defaultID
    private var lightID = ThemeVariant.light.defaultID
    private var opacity: Double?
    private var blur = true
    private var loadedFileIssues: [ThemeFileIssue]?
    private var fileNamesByID: [String: String] = [:]
    private var selectedFileNames: [String: String] = [:]

    private(set) var hasThemeFolder = false

    private(set) var catalog = ThemeCatalog()
    private(set) var issues: [ThemeDefinition.Issue] = []
    private(set) var userDefinitions: [ThemeDefinition] = []

    var fileIssues: [ThemeFileIssue] {
        guard let loadedFileIssues else { return [] }
        return loadedFileIssues + issues.compactMap { issue in
            guard case .unavailableSelection(let id, _) = issue else { return nil }
            return ThemeFileIssue(fileName: selectedFileNames[id], problem: .definition(issue))
        }
    }

    init(appliesThemes: Bool) {
        self.appliesThemes = appliesThemes
    }

    func apply(darkID: String, lightID: String, opacity: Double?, blur: Bool) {
        self.darkID = darkID
        self.lightID = lightID
        self.opacity = opacity
        self.blur = blur
        resolve()
    }

    func applyFiles(_ snapshot: ThemeFileRepository.Snapshot) {
        let firstLoad = loadedFileIssues == nil
        if hasThemeFolder != snapshot.folderExists { hasThemeFolder = snapshot.folderExists }
        if loadedFileIssues != snapshot.issues { loadedFileIssues = snapshot.issues }
        if fileNamesByID != snapshot.fileNamesByID { fileNamesByID = snapshot.fileNamesByID }

        let definitionsChanged = userDefinitions != snapshot.definitions
        if definitionsChanged {
            userDefinitions = snapshot.definitions
            catalog = ThemeCatalog(userDefinitions: userDefinitions)
        }
        if firstLoad || definitionsChanged {
            resolve()
        } else {
            rememberSelectedFileNames()
        }
    }

    private func rememberSelectedFileNames() {
        let selectedIDs = Set([darkID, lightID])
        var names = selectedFileNames.filter { selectedIDs.contains($0.key) }
        for id in selectedIDs {
            if let name = fileNamesByID[id] { names[id] = name }
        }
        if names != selectedFileNames { selectedFileNames = names }
    }

    private func resolve() {
        rememberSelectedFileNames()
        let dark = catalog.resolve(id: darkID, variant: .dark)
        let light = catalog.resolve(id: lightID, variant: .light)
        let selectionIssues = (dark.issues + light.issues).filter { issue in
            guard loadedFileIssues == nil, case .unavailableSelection(let id, _) = issue else { return true }
            return catalog.definitions.contains { $0.id == id }
        }
        let nextIssues = catalog.issues + selectionIssues
        if nextIssues != issues {
            issues = nextIssues
            if appliesThemes {
                for issue in nextIssues {
                    Self.logger.warning("Theme resolution issue: \(String(describing: issue), privacy: .private)")
                }
            }
        }
        if appliesThemes {
            ThemeRendering.shared.apply(
                ThemePresentation(
                    dark: dark.palette, light: light.palette, windowOpacity: opacity, windowBlur: blur))
        }
    }
}
