import Foundation

struct ThemeFileIssue: Hashable, Sendable {
    let fileName: String?
    let problem: Problem

    enum Problem: Hashable, Sendable {
        case definition(ThemeDefinition.Issue)
        case reservedID(String)
        case unreadable
        case fileTooLarge
        case tooManyFiles
        case folderTooLarge
        case moreFileIssues
    }

    var message: String {
        let location = fileName ?? String(localized: "Themes folder")
        return "\(location) — \(detail)"
    }

    var detail: String {
        switch problem {
        case .definition(let issue): Self.describe(issue)
        case .reservedID(let id): String(localized: "Theme ID “\(id.prefix(120))” is reserved for a built-in theme.")
        case .unreadable: String(localized: "Tinycast couldn’t read this location.")
        case .fileTooLarge: String(localized: "The theme file exceeds 256 KB.")
        case .tooManyFiles: String(localized: "Only the first 200 theme files are loaded.")
        case .folderTooLarge: String(localized: "The themes folder exceeds the 2 MB loading limit.")
        case .moreFileIssues: String(localized: "This file has further issues.")
        }
    }

    private static func describe(_ issue: ThemeDefinition.Issue) -> String {
        switch issue {
        case .invalidJSON: String(localized: "The theme file contains invalid JSON.")
        case .invalidField(let key): String(localized: "Invalid theme field “\(key)”.")
        case .unknownKey(let key): String(localized: "Unknown theme key “\(key.prefix(120))”.")
        case .invalidColor(let key): String(localized: "Invalid colour for “\(key)”.")
        case .duplicateID(let id): String(localized: "Duplicate theme ID “\(id.prefix(120))”.")
        case .missingParent(_, let parent): String(localized: "Parent theme “\(parent.prefix(120))” is missing.")
        case .incompatibleParent(_, let parent):
            String(localized: "Parent theme “\(parent.prefix(120))” has a different variant.")
        case .cycle: String(localized: "This theme is part of an inheritance cycle.")
        case .unavailableSelection(let id, let variant):
            switch variant {
            case .dark: String(localized: "Dark theme “\(id.prefix(120))” is unavailable.")
            case .light: String(localized: "Light theme “\(id.prefix(120))” is unavailable.")
            }
        }
    }
}
