import Foundation

@MainActor
final class ThemeFileMonitor {
    private struct Watch {
        let id: UUID
        let source: DispatchSourceFileSystemObject
    }

    private let folder: URL
    private let onLoad: (ThemeFileRepository.Snapshot) -> Void
    private let directoryChain: [URL]
    private var directoryWatches: [URL: Watch] = [:]
    private var fileWatches: [URL: Watch] = [:]
    private var reloadTask: Task<Void, Never>?
    private var isStarted = false

    private static let invalidated: DispatchSource.FileSystemEvent = [.delete, .rename, .revoke]

    init(folder: URL, onLoad: @escaping (ThemeFileRepository.Snapshot) -> Void) {
        self.folder = folder
        self.onLoad = onLoad
        directoryChain = sequence(first: folder.standardizedFileURL) { directory in
            guard directory.path != "/" else { return nil }
            return directory.deletingLastPathComponent()
        }.reversed().filter { $0.path != "/" }
    }

    isolated deinit {
        stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        scheduleReload(after: .zero)
    }

    func stop() {
        isStarted = false
        reloadTask?.cancel()
        reloadTask = nil
        for watch in directoryWatches.values { watch.source.cancel() }
        directoryWatches.removeAll()
        for watch in fileWatches.values { watch.source.cancel() }
        fileWatches.removeAll()
    }

    private func scheduleReload(after delay: Duration) {
        guard isStarted else { return }
        reloadTask?.cancel()
        reloadTask = Task { [weak self, folder] in
            do {
                if delay > .zero { try await Task.sleep(for: delay) }
                try Task.checkCancellation()
                self?.watchDirectories()
                let snapshot = try await ThemeFileRepository.load(folder)
                try Task.checkCancellation()
                self?.publish(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.publish(ThemeFileRepository.Snapshot(
                    issues: [ThemeFileIssue(fileName: nil, problem: .unreadable)]))
            }
        }
    }

    private func publish(_ snapshot: ThemeFileRepository.Snapshot) {
        let paths = Set(snapshot.watchedFiles)
        for path in Array(fileWatches.keys) where !paths.contains(path) {
            fileWatches.removeValue(forKey: path)?.source.cancel()
        }
        var armedFile = false
        for path in paths where fileWatches[path] == nil {
            guard let watch = makeWatch(path, directory: false) else { continue }
            fileWatches[path] = watch
            armedFile = true
        }
        // A file can change between reading it and arming its source.
        if armedFile {
            scheduleReload(after: .zero)
        } else {
            onLoad(snapshot)
            let unreadableFiles = Set(snapshot.issues.compactMap { $0.problem == .unreadable ? $0.fileName : nil })
            let missedFile = paths.contains { fileWatches[$0] == nil && !unreadableFiles.contains($0.lastPathComponent) }
            let missedFolder = snapshot.folderExists && directoryWatches[directoryChain.last ?? folder] == nil
            if missedFile || missedFolder {
                scheduleReload(after: .seconds(1))
            }
        }
    }

    private func watchDirectories() {
        for path in directoryChain where directoryWatches[path] == nil {
            directoryWatches[path] = makeWatch(path, directory: true)
        }
    }

    private func makeWatch(_ url: URL, directory: Bool) -> Watch? {
        let id = UUID()
        let events: DispatchSource.FileSystemEvent = [.write, .extend, .attrib, Self.invalidated]
        let source = FileSystemEventSource.watch(url, directory: directory, events: events) { [weak self] events in
            let flags = events.rawValue
            Task { @MainActor in
                self?.changed(url, id: id, directory: directory, events: .init(rawValue: flags))
            }
        }
        return source.map { Watch(id: id, source: $0) }
    }

    private func changed(_ url: URL, id: UUID, directory: Bool, events: DispatchSource.FileSystemEvent) {
        let invalidated = !events.isDisjoint(with: Self.invalidated)
        if directory {
            guard directoryWatches[url]?.id == id, let index = directoryChain.firstIndex(of: url) else { return }
            if invalidated {
                for path in directoryChain[index...] {
                    directoryWatches.removeValue(forKey: path)?.source.cancel()
                }
                for watch in fileWatches.values { watch.source.cancel() }
                fileWatches.removeAll()
            } else if index + 1 < directoryChain.count, directoryWatches[directoryChain[index + 1]] != nil {
                return
            }
        } else {
            guard fileWatches[url]?.id == id else { return }
            if invalidated { fileWatches.removeValue(forKey: url)?.source.cancel() }
        }
        scheduleReload(after: .milliseconds(150))
    }
}
