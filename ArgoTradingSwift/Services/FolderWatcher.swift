//
//  FolderWatcher.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import Foundation

enum FileChangeEvent {
    case folderChanged
    case folderDeleted
    case folderRecreated
    case fileCreated(URL)
    case fileModified(URL)
    case fileDeleted(URL)
}

class FolderMonitor {
    private let url: URL
    private var streamRef: FSEventStreamRef?
    private var parentMonitor: DispatchSourceFileSystemObject?
    private var parentDescriptor: Int32 = -1
    private var continuation: AsyncStream<FileChangeEvent>.Continuation?
    private var folderExists: Bool = false

    init(url: URL) {
        self.url = url
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() -> AsyncStream<FileChangeEvent> {
        print("Start monitoring folder: \(url.path)")
        return AsyncStream { continuation in
            self.continuation = continuation
            self.folderExists = FileManager.default.fileExists(atPath: self.url.path)

            // Set up parent folder monitoring for deletion/recreation detection
            self.setupParentMonitor()

            // Set up FSEvents monitoring for file changes
            if self.folderExists {
                self.setupFSEventsMonitor()
            }

            continuation.onTermination = { [weak self] _ in
                self?.stopMonitoring()
            }
        }
    }

    private func setupParentMonitor() {
        let parentURL = url.deletingLastPathComponent()

        parentDescriptor = open(parentURL.path, O_EVTONLY)
        guard parentDescriptor != -1 else {
            print("Failed to open parent directory: \(parentURL.path)")
            return
        }

        parentMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: parentDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        parentMonitor?.setEventHandler { [weak self] in
            guard let self = self else { return }

            let currentlyExists = FileManager.default.fileExists(atPath: self.url.path)

            if !self.folderExists && currentlyExists {
                // Folder was recreated
                print("Target folder was recreated")
                self.folderExists = true
                self.setupFSEventsMonitor()
                self.continuation?.yield(.folderRecreated)
            } else if self.folderExists && !currentlyExists {
                // Folder was deleted
                print("Target folder was deleted")
                self.folderExists = false
                self.stopFSEventsMonitor()
                self.continuation?.yield(.folderDeleted)
            }
        }

        parentMonitor?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.parentDescriptor != -1 {
                close(self.parentDescriptor)
                self.parentDescriptor = -1
            }
        }

        parentMonitor?.resume()
    }

    private func setupFSEventsMonitor() {
        // Stop existing FSEvents monitor if any
        stopFSEventsMonitor()

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Folder does not exist: \(url.path)")
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [url.path] as CFArray

        let callback: FSEventStreamCallback = { (
            _: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            _: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let monitor = Unmanaged<FolderMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()

            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for i in 0..<numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                let fileURL = URL(fileURLWithPath: path)

                DispatchQueue.main.async {
                    if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                        print("File deleted: \(path)")
                        monitor.continuation?.yield(.fileDeleted(fileURL))
                    } else if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                        print("File created: \(path)")
                        monitor.continuation?.yield(.fileCreated(fileURL))
                    } else if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
                        print("File modified: \(path)")
                        monitor.continuation?.yield(.fileModified(fileURL))
                    } else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                        // Renamed can mean created or deleted depending on context
                        if FileManager.default.fileExists(atPath: path) {
                            print("File renamed/created: \(path)")
                            monitor.continuation?.yield(.fileCreated(fileURL))
                        } else {
                            print("File renamed/deleted: \(path)")
                            monitor.continuation?.yield(.fileDeleted(fileURL))
                        }
                    } else {
                        // Generic change
                        print("Folder changed: \(path)")
                        monitor.continuation?.yield(.folderChanged)
                    }
                }
            }
        }

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // Latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let streamRef = streamRef else {
            print("Failed to create FSEventStream")
            return
        }

        FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(streamRef)
        print("FSEvents monitoring started for: \(url.path)")
    }

    private func stopFSEventsMonitor() {
        if let streamRef = streamRef {
            FSEventStreamStop(streamRef)
            FSEventStreamInvalidate(streamRef)
            FSEventStreamRelease(streamRef)
            self.streamRef = nil
        }
    }

    private func cleanupMonitors() {
        // Clean up FSEvents monitor
        stopFSEventsMonitor()

        // Clean up parent monitor
        parentMonitor?.cancel()
        parentMonitor = nil
    }

    func stopMonitoring() {
        print("Stop monitoring folder")
        cleanupMonitors()
        continuation?.finish()
        continuation = nil
    }
}
