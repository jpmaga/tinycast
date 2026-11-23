import Darwin
import Foundation

enum FileSystemEventSource {
    static func watch(
        _ url: URL, directory: Bool = false, events: DispatchSource.FileSystemEvent,
        onChange: @escaping @Sendable (DispatchSource.FileSystemEvent) -> Void
    ) -> DispatchSourceFileSystemObject? {
        let flags = directory ? O_EVTONLY | O_DIRECTORY | O_CLOEXEC : O_EVTONLY | O_CLOEXEC
        let descriptor = Darwin.open(url.path, flags)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak source] in
            if let source { onChange(source.data) }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        return source
    }
}
