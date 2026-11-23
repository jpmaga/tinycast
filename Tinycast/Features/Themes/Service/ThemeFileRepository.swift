import Darwin
import Foundation

enum ThemeFileRepository {
    struct Snapshot: Equatable, Sendable {
        var folderExists = false
        var definitions: [ThemeDefinition] = []
        var fileNamesByID: [String: String] = [:]
        var issues: [ThemeFileIssue] = []
        var watchedFiles: [URL] = []
        fileprivate var bytesLoaded = 0
        fileprivate var acceptsNewFile = true
    }

    enum CreationError: Error {
        case folderLimit
    }

    static let maximumFileCount = 200
    static let maximumFileBytes = 256_000
    static let maximumFolderBytes = 2_000_000
    private static let maximumFileIssues = 8

    @concurrent
    static func load(_ folder: URL) async throws -> Snapshot {
        try scan(folder)
    }

    @concurrent
    static func createStarter(
        in folder: URL, variant: ThemeVariant, selectedID: String, name: String
    ) async throws -> URL {
        let snapshot = try scan(folder)
        guard !snapshot.issues.contains(ThemeFileIssue(fileName: nil, problem: .unreadable))
        else { throw CocoaError(.fileReadUnknown) }
        guard snapshot.acceptsNewFile else { throw CreationError.folderLimit }
        let catalog = ThemeCatalog(userDefinitions: snapshot.definitions)
        let parentID = catalog.definitions.first { $0.id == selectedID && $0.variant == variant }?.id
            ?? variant.defaultID
        let colours = catalog.resolve(id: parentID, variant: variant).palette.overrides
        let usedIDs = Set(catalog.definitions.map(\.id))

        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for number in 1...(maximumFileCount + 1) {
            try Task.checkCancellation()
            let id = number == 1 ? "my-theme" : "my-theme-\(number)"
            if usedIDs.contains(id) { continue }
            let url = folder.appending(path: "\(id).json", directoryHint: .notDirectory)
            let displayName = number == 1 ? name : "\(name) \(number)"
            let object: [String: Any] = [
                "id": id, "name": displayName, "variant": variant.rawValue, "inherits": parentID,
                "colors": Dictionary(uniqueKeysWithValues: colours.map { ($0.key.rawValue, $0.value.hex) })
            ]
            var data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            data.append(0x0A)
            guard data.count <= maximumFileBytes, snapshot.bytesLoaded + data.count <= maximumFolderBytes
            else { throw CreationError.folderLimit }
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }

    private static func scan(_ folder: URL) throws -> Snapshot {
        var snapshot = Snapshot()
        let files: [URL]
        do {
            files = try candidates(in: folder, snapshot: &snapshot)
        } catch CocoaError.fileReadNoSuchFile {
            return Snapshot()
        } catch {
            try Task.checkCancellation()
            snapshot.issues = [ThemeFileIssue(fileName: nil, problem: .unreadable)]
            return snapshot
        }

        let reserved = Set(ThemeCatalog.builtIns.map(\.id))
        for url in files {
            try Task.checkCancellation()
            snapshot.watchedFiles.append(url)
            let name = url.lastPathComponent
            let (data, problem) = read(url)
            if let problem {
                snapshot.issues.append(ThemeFileIssue(fileName: name, problem: problem))
            }
            guard let data else { continue }
            if snapshot.bytesLoaded + data.count > maximumFolderBytes {
                snapshot.issues.append(ThemeFileIssue(fileName: name, problem: .folderTooLarge))
                snapshot.acceptsNewFile = false
                break
            }
            snapshot.bytesLoaded += data.count
            let decoded = ThemeDefinition.decode(data)
            for issue in decoded.issues.prefix(maximumFileIssues) {
                snapshot.issues.append(ThemeFileIssue(fileName: name, problem: .definition(issue)))
            }
            if decoded.issues.count > maximumFileIssues {
                snapshot.issues.append(ThemeFileIssue(fileName: name, problem: .moreFileIssues))
            }
            guard let definition = decoded.definition else { continue }
            if reserved.contains(definition.id) {
                snapshot.issues.append(ThemeFileIssue(fileName: name, problem: .reservedID(definition.id)))
            } else if snapshot.fileNamesByID[definition.id] != nil {
                snapshot.issues.append(
                    ThemeFileIssue(fileName: name, problem: .definition(.duplicateID(definition.id))))
            } else {
                snapshot.definitions.append(definition)
                snapshot.fileNamesByID[definition.id] = name
            }
        }
        try recordInheritanceIssues(in: &snapshot)
        return snapshot
    }

    private static func candidates(in folder: URL, snapshot: inout Snapshot) throws -> [URL] {
        snapshot.folderExists = try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        guard snapshot.folderExists else { throw CocoaError(.fileReadUnknown) }

        var enumerationError: Error?
        guard let entries = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else { throw CocoaError(.fileReadUnknown) }

        var urls: [URL] = []
        var exceededCount = false
        for case let url as URL in entries {
            try Task.checkCancellation()
            guard url.pathExtension.lowercased() == "json",
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) != false
            else { continue }

            if urls.count == maximumFileCount {
                exceededCount = true
                guard let last = urls.last, url.lastPathComponent < last.lastPathComponent else { continue }
                urls.removeLast()
            }
            let index = urls.firstIndex { url.lastPathComponent < $0.lastPathComponent } ?? urls.endIndex
            urls.insert(url, at: index)
        }
        if let enumerationError { throw enumerationError }
        if exceededCount {
            snapshot.issues.append(ThemeFileIssue(fileName: nil, problem: .tooManyFiles))
        }
        snapshot.acceptsNewFile = urls.count < maximumFileCount
        return urls
    }

    private static func read(_ url: URL) -> (Data?, ThemeFileIssue.Problem?) {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            return errno == ENOENT ? (nil, nil) : (nil, .unreadable)
        }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var status = stat()
        guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG else {
            return (nil, .unreadable)
        }
        guard status.st_size <= maximumFileBytes else { return (nil, .fileTooLarge) }
        do {
            let data = try file.read(upToCount: maximumFileBytes + 1) ?? Data()
            return data.count <= maximumFileBytes ? (data, nil) : (nil, .fileTooLarge)
        } catch {
            return (nil, .unreadable)
        }
    }

    private static func recordInheritanceIssues(in snapshot: inout Snapshot) throws {
        let catalog = ThemeCatalog(userDefinitions: snapshot.definitions)
        for definition in snapshot.definitions {
            try Task.checkCancellation()
            let result = catalog.resolve(id: definition.id, variant: definition.variant)
            for issue in result.issues {
                switch issue {
                case .missingParent(let id, _) where id == definition.id,
                    .incompatibleParent(let id, _) where id == definition.id:
                    break
                case .cycle(let path) where path.last == definition.id:
                    break
                default:
                    continue
                }
                snapshot.issues.append(ThemeFileIssue(
                    fileName: snapshot.fileNamesByID[definition.id], problem: .definition(issue)))
            }
        }
    }
}
