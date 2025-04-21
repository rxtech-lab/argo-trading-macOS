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
    private var task: Task<Void, Never>?
    private var parentMonitor: DispatchSourceFileSystemObject?
    private var parentDescriptor: Int32 = -1
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() -> AsyncStream<FileChangeEvent> {
        print("Start monitoring folder: \(url.path)")
        return AsyncStream { continuation in
            // First set up parent folder monitoring
            setupParentMonitor(continuation: continuation)
            
            // Then set up target folder monitoring
            setupFolderMonitor(continuation: continuation)
            
            continuation.onTermination = { _ in
                self.cleanupMonitors()
            }
        }
    }
    
    private func setupParentMonitor(continuation: AsyncStream<FileChangeEvent>.Continuation) {
        guard let parentURL = url.deletingLastPathComponent().absoluteURL as URL? else {
            print("Could not determine parent folder")
            return
        }
        
        parentDescriptor = open(parentURL.path, O_EVTONLY)
        guard parentDescriptor != -1 else {
            print("Failed to open parent directory: \(parentURL.path)")
            return
        }
        
        parentMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: parentDescriptor,
            eventMask: [.all],
            queue: .main) // Change to main queue
        
        parentMonitor?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Check if our target folder exists
            let folderExists = FileManager.default.fileExists(atPath: self.url.path)
            
            if folderExists {
                // If folder exists but we're receiving an event, it might have been recreated
                print("Parent folder changed, checking if target folder was recreated")
                // Set up monitoring again
                self.setupFolderMonitor(continuation: continuation)
                continuation.yield(.folderRecreated)
            } else {
                // Target folder might have been deleted
                print("Target folder was deleted")
                continuation.yield(.folderDeleted)
            }
        }
        
        parentMonitor?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.parentDescriptor)
            self.parentDescriptor = -1
        }
        
        parentMonitor?.resume()
    }
    
    private func setupFolderMonitor(continuation: AsyncStream<FileChangeEvent>.Continuation) {
        // Make sure folder exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Folder does not exist: \(url.path)")
            return
        }
        
        Task {
            for await _ in self.monitorFolder() {
                // Dispatch to main thread
                await MainActor.run {
                    print("Folder changed")
                    
                    do {
                        // Get the current list of files
                        let _ = try FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: nil)
                        
                        // Determine if files were added, modified, or deleted
                        continuation.yield(.folderChanged)
                    } catch {
                        print("Error reading directory contents: \(error)")
                    }
                }
            }
        }
    }
    
    private func monitorFolder() -> AsyncStream<Void> {
        return AsyncStream { continuation in
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor != -1 else {
                print("Failed to open directory: \(url.path)")
                continuation.finish()
                return
            }
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.all],
                queue: .main) // Change to main queue
            
            source.setEventHandler {
                continuation.yield()
            }
            
            source.setCancelHandler {
                close(descriptor)
                continuation.finish()
            }
            
            source.resume()
            
            continuation.onTermination = { _ in
                source.cancel()
            }
        }
    }
    
    private func cleanupMonitors() {
        // Clean up parent monitor
        parentMonitor?.cancel()
        if parentDescriptor != -1 {
            close(parentDescriptor)
            parentDescriptor = -1
        }
    }
    
    func stopMonitoring() {
        print("Stop monitoring folder")
        task?.cancel()
        task = nil
        cleanupMonitors()
    }
}
