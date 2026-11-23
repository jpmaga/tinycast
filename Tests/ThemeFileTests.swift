import Foundation
import Observation
import Synchronization

@main
@MainActor
enum ThemeFileTests {
    private static var failures = 0
    private static var passes = 0

    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try await loading(in: root.appending(path: "loading"))
        try await limits(in: root.appending(path: "limits"))
        selectionBeforeFirstLoad()
        try await monitoring(in: root.appending(path: "monitoring"))
        try await starter(in: root.appending(path: "starter"))
        check("stable themes use the stable config folder", AppPaths.themesFolder(bundleID: "com.abueammar.tinycast")
            .path.hasSuffix("/.config/tinycast/themes"))
        check("Debug themes use the Dev config folder", AppPaths.themesFolder(bundleID: "com.abueammar.tinycast.dev")
            .path.hasSuffix("/.config/tinycast-dev/themes"))

        print("\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    private static func loading(in folder: URL) async throws {
        let absent = try await ThemeFileRepository.load(folder)
        check("missing folder is normal", !absent.folderExists && absent.definitions.isEmpty && absent.issues.isEmpty)
        check("loading does not create a folder", !FileManager.default.fileExists(atPath: folder.path))

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write("z.json", theme("shared", name: "Later"), in: folder)
        try write("a.json", theme("shared", name: "First"), in: folder)
        try write("b.json", "{", in: folder)
        try write("c.json", theme("nord"), in: folder)
        try write("d.json", theme("missing", fields: #","inherits":"absent""#), in: folder)
        try write("e.json", theme("wrong", fields: #","inherits":"tinycast-light""#), in: folder)
        try write("f.json", theme("cycle-a", fields: #","inherits":"cycle-b""#), in: folder)
        try write("g.json", theme("cycle-b", fields: #","inherits":"cycle-a""#), in: folder)
        try write("h.json", theme("broken", fields:
            ##","extra":true,"colors":{"accent":"blue","row_hover":"#ABC","selection":"#4567AB89"}"##), in: folder)
        try write(".hidden.json", theme("hidden"), in: folder)
        try write("ignored.txt", theme("ignored"), in: folder)
        let nested = folder.appending(path: "nested.json", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try write("nested.json", theme("nested"), in: nested)
        try FileManager.default.createSymbolicLink(
            at: folder.appending(path: "linked.json"), withDestinationURL: folder.appending(path: "a.json"))

        let snapshot = try await ThemeFileRepository.load(folder)
        let diagnostics = snapshot.issues
        check("keeps definitions in filename order", snapshot.definitions.map(\.id)
            == ["shared", "missing", "wrong", "cycle-a", "cycle-b", "broken"])
        check("ignores hidden, non-JSON, nested and symbolic link entries", diagnostics.count == 10)
        check("first file wins duplicate ID", snapshot.definitions.first?.name == "First"
            && snapshot.fileNamesByID["shared"] == "a.json")
        check("invalid JSON names the file", diagnostics.contains(issue("b.json", .definition(.invalidJSON))))
        check("reserved ID names the file", diagnostics.contains(issue("c.json", .reservedID("nord"))))
        check("duplicate ID names the later file", diagnostics.contains(issue("z.json", .definition(.duplicateID("shared")))))
        check("missing parent diagnosed without selecting the theme",
            diagnostics.contains(issue("d.json", .definition(.missingParent(theme: "missing", parent: "absent")))))
        check("incompatible parent names the file", diagnostics.contains(
            issue("e.json", .definition(.incompatibleParent(theme: "wrong", parent: "tinycast-light")))))
        check("each cycle member names its own file", diagnostics.contains(
            issue("f.json", .definition(.cycle(["cycle-a", "cycle-b", "cycle-a"])))) && diagnostics.contains(
            issue("g.json", .definition(.cycle(["cycle-b", "cycle-a", "cycle-b"])))))
        check("unknown key and bad colour name the file", diagnostics.contains(
            issue("h.json", .definition(.unknownKey("extra")))) && diagnostics.contains(
            issue("h.json", .definition(.invalidColor("colors.accent")))))
        check("removed colour key is reported and skipped",
            diagnostics.contains(issue("h.json", .definition(.unknownKey("colors.row_hover"))))
                && snapshot.definitions.last?.colors == [.selection: ThemeColor(rgb: 0x4567AB, alpha: 137.0 / 255)])
    }

    private static func limits(in folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let count = ThemeFileRepository.maximumFileCount
        for index in (1...count).reversed() {
            let filename = String(format: "%03d.json", index)
            try write(filename, theme("theme-\(index)"), in: folder)
        }
        try write("000.json", String(repeating: " ", count: ThemeFileRepository.maximumFileBytes + 1), in: folder)

        let snapshot = try await ThemeFileRepository.load(folder)
        check("oversized file is skipped with a diagnostic", snapshot.issues.contains(issue("000.json", .fileTooLarge)))
        check("count cap applies in filename order", snapshot.definitions.count == count - 1
            && snapshot.definitions.last?.id == "theme-\(count - 1)"
            && snapshot.issues.contains(ThemeFileIssue(fileName: nil, problem: .tooManyFiles)))
        do {
            _ = try await ThemeFileRepository.createStarter(in: folder, variant: .dark, selectedID: "nord", name: "Mine")
            check("full folder refuses a starter", false)
        } catch ThemeFileRepository.CreationError.folderLimit {
            check("full folder refuses a starter", true)
        }

        let aggregate = folder.appending(path: "aggregate", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: aggregate, withIntermediateDirectories: false)
        for index in 1...9 {
            let json = theme("large-\(index)")
            let padding = String(repeating: " ", count: 250_000 - json.utf8.count)
            try write("\(index).json", json + padding, in: aggregate)
        }
        let capped = try await ThemeFileRepository.load(aggregate)
        check("total decoding stays within the folder byte budget", capped.definitions.count == 8
            && capped.issues.contains(issue("9.json", .folderTooLarge)))
    }

    private static func selectionBeforeFirstLoad() {
        let store = ThemeStore(appliesThemes: false)
        store.apply(darkID: "missing", lightID: "tinycast-light", opacity: nil, blur: true)
        check("an unknown user selection is quiet before the first load", store.issues.isEmpty)

        let snapshot = ThemeFileRepository.Snapshot()
        store.applyFiles(snapshot)
        check("the first empty load reports the missing selection",
            store.fileIssues == [ThemeFileIssue(
                fileName: nil, problem: .definition(.unavailableSelection(id: "missing", variant: .dark)))])

        let invalidated = Mutex(false)
        withObservationTracking {
            _ = store.hasThemeFolder
            _ = store.fileIssues
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        store.applyFiles(snapshot)
        check("an identical snapshot leaves observers alone", !invalidated.withLock { $0 })
    }

    private static func monitoring(in root: URL) async throws {
        let parent = root.appending(path: "config", directoryHint: .isDirectory)
        let folder = parent.appending(path: "themes", directoryHint: .isDirectory)
        let file = folder.appending(path: "test.json")
        let store = ThemeStore(appliesThemes: true)
        let settingsStore = ThemeStore(appliesThemes: false)
        store.apply(darkID: "live", lightID: "tinycast-light", opacity: nil, blur: true)
        settingsStore.apply(darkID: "nord", lightID: "tinycast-light", opacity: nil, blur: true)
        var snapshots = 0
        let monitor = ThemeFileMonitor(folder: folder) { snapshot in
            snapshots += 1
            store.applyFiles(snapshot)
            settingsStore.applyFiles(snapshot)
        }
        monitor.start()
        defer {
            monitor.stop()
            ThemeRendering.shared.apply(ThemePresentation())
        }

        await expect("monitor starts with no folder") { snapshots > 0 && !store.hasThemeFolder }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write("test.json", theme("live", fields: ##","colors":{"background":"#123456"}"##), in: folder)
        await expect("monitor picks up folder and file creation") {
            ThemeRendering.shared.presentation.dark.background.hex == "#123456"
        }
        check("Settings gets the catalogue and leaves the rendering selection alone",
            settingsStore.catalog.definitions.contains { $0.id == "live" }
                && ThemeRendering.shared.presentation.dark.background.hex == "#123456")
        let stableSnapshots = snapshots
        try await Task.sleep(for: .milliseconds(250))
        check("a stable folder produces no more snapshots", snapshots == stableSnapshots)

        try write("test.json", theme("live", fields: ##","colors":{"background":"#223344"}"##), in: folder)
        await expect("in-place edits update the selected theme") {
            ThemeRendering.shared.presentation.dark.background.hex == "#223344"
        }

        let beforeBurst = snapshots
        try write("test.json", theme("live", name: "First write"), in: folder)
        try await Task.sleep(for: .milliseconds(40))
        try write("test.json", theme("live", name: "Last write"), in: folder)
        await expect("the burst loads its final write") {
            store.userDefinitions.first?.name == "Last write"
        }
        try await Task.sleep(for: .milliseconds(250))
        check("a burst of writes publishes exactly one snapshot", snapshots == beforeBurst + 1)

        try Data(theme("live", fields: ##","colors":{"background":"#ABCDEF"}"##).utf8).write(to: file, options: .atomic)
        await expect("save by rename updates the selected theme") {
            ThemeRendering.shared.presentation.dark.background.hex == "#ABCDEF"
        }

        try write("test.json", theme("live", fields: ##","colors":{"background":"#778899"}"##), in: folder)
        await expect("the replaced file continues to receive in-place edits") {
            ThemeRendering.shared.presentation.dark.background.hex == "#778899"
        }

        try FileManager.default.removeItem(at: file)
        await expect("deletion reverts rendering and reports the selected filename") {
            ThemeRendering.shared.presentation.dark.isBaseline && store.fileIssues.contains(
                issue("test.json", .definition(.unavailableSelection(id: "live", variant: .dark))))
        }

        try write("test.json", theme("live", fields: ##","colors":{"background":"#123456"}"##), in: folder)
        await expect("restoring the file restores the saved selection") {
            store.fileIssues.isEmpty && ThemeRendering.shared.presentation.dark.background.hex == "#123456"
        }

        let oldFolder = root.appending(path: "old-config", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: parent, to: oldFolder)
        await expect("renaming the config directory removes the themes") {
            !store.hasThemeFolder && ThemeRendering.shared.presentation.dark.isBaseline
        }
        try FileManager.default.moveItem(at: oldFolder, to: parent)
        await expect("renaming the config directory back reloads the themes") {
            store.hasThemeFolder && ThemeRendering.shared.presentation.dark.background.hex == "#123456"
        }

        try FileManager.default.removeItem(at: folder)
        await expect("removing the themes directory is detected") {
            !store.hasThemeFolder && ThemeRendering.shared.presentation.dark.isBaseline
        }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write("test.json", theme("live"), in: folder)
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions]
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: permissions ?? 0o600], ofItemAtPath: file.path) }
        await expect("the monitor reports an unreadable file") {
            store.fileIssues.contains(issue("test.json", .unreadable))
        }
        let unreadableSnapshots = snapshots
        try await Task.sleep(for: .milliseconds(1250))
        check("an unreadable file does not trigger retries", snapshots == unreadableSnapshots)

        monitor.stop()
        try write("new.json", theme("new"), in: folder)
        try await Task.sleep(for: .milliseconds(250))
        check("stopping the monitor prevents further snapshots", snapshots == unreadableSnapshots)
    }

    private static func starter(in folder: URL) async throws {
        let first = try await ThemeFileRepository.createStarter(
            in: folder, variant: .dark, selectedID: "nord", name: "Mine")
        let firstData = try Data(contentsOf: first)
        let decoded = ThemeDefinition.decode(firstData)
        check("starter creates the folder and writes strict JSON", decoded.issues.isEmpty && firstData.last == 0x0A)
        check("starter inherits and copies the selected theme", decoded.definition?.id == "my-theme"
            && decoded.definition?.variant == .dark && decoded.definition?.inherits == "nord"
            && decoded.definition?.colors[.accent]?.hex == "#88C0D0")

        try write("other.json", theme("my-theme-2"), in: folder)
        try write("my-theme-3.json", "{", in: folder)
        let second = try await ThemeFileRepository.createStarter(
            in: folder, variant: .light, selectedID: "nord", name: "Mine")
        let next = ThemeDefinition.decode(try Data(contentsOf: second))
        check("starter avoids existing filenames and IDs", second.lastPathComponent == "my-theme-4.json"
            && next.definition?.id == "my-theme-4")
        check("unavailable parent uses the current variant's default",
            next.definition?.variant == .light && next.definition?.inherits == "tinycast-light")
        let snapshot = try await ThemeFileRepository.load(folder)
        let catalog = ThemeCatalog(userDefinitions: snapshot.definitions)
        check("starter with a default parent preserves baseline rendering",
            catalog.resolve(id: "my-theme-4", variant: .light).palette.isBaseline)
        check("starter never overwrites a file", try Data(contentsOf: first) == firstData)
    }

    private static func theme(_ id: String, name: String = "Theme", fields: String = "") -> String {
        #"{"id":"\#(id)","name":"\#(name)","variant":"dark"\#(fields)}"#
    }

    private static func write(_ filename: String, _ contents: String, in folder: URL) throws {
        try Data(contents.utf8).write(to: folder.appending(path: filename, directoryHint: .notDirectory))
    }

    private static func issue(_ fileName: String, _ problem: ThemeFileIssue.Problem) -> ThemeFileIssue {
        ThemeFileIssue(fileName: fileName, problem: problem)
    }

    private static func expect(_ label: String, until condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(4)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        check(label, condition())
    }

    private static func check(_ label: String, _ result: Bool) {
        if result {
            passes += 1
        } else {
            failures += 1
            print("FAIL  \(label)")
        }
    }
}
