//
//  ClipboardListener.swift
//  Clipline
//
//  Created by mazhj on 2025/11/30.
//

import AppKit
import Combine
import CryptoKit
import Foundation

class ClipboardListener: @unchecked Sendable {
    
    enum Err: Error {
        case listenError
        case shutdownError
    }
    
    private var timer: DispatchSourceTimer?
    private let checkInterval: TimeInterval = 0.2
    private var lastChangeCount: Int
    private let repo: ClipboardRepository
    private let queue: DispatchQueue
    
    var onCopy: (String) -> Bool = {_ in true}
    var onParsed: (NSPasteboard.ParsedResult) -> Bool = {_ in true}
    var cleanRulesGetter: () -> [NSPasteboard.CleanRule] = { [] }

    init(repo: ClipboardRepository) throws {
        self.repo = repo
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.queue = DispatchQueue(label: "com.mazen.clipline.clipboard-listener.queue", qos: .utility)
    }
    
    func listen() throws {
        if timer != nil { try shutdown() }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        
        timer.schedule(deadline: .now(), repeating: checkInterval)
        
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
    }
    
    func shutdown() throws {
        guard let timer = self.timer else { throw Err.shutdownError }
        timer.cancel()
        self.timer = nil
    }
    
    private func tick() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        
        
        var snapshot: NSPasteboard.PasteboardSnapshot?
        
        DispatchQueue.main.sync {
            if NSPasteboard.general.changeCount == self.lastChangeCount { return }
            self.lastChangeCount = NSPasteboard.general.changeCount
            snapshot = NSPasteboard.general.createSnapshot()
        }
        
        guard let safeSnapshot = snapshot, onCopy(safeSnapshot.sourceAppBundleID) else { return }
        guard let parsedResult = NSPasteboard.parseSnapshot(snapshot: safeSnapshot), onParsed(parsedResult) else { return }
        
        repo.save(parsedResult, sourceApp: safeSnapshot.sourceAppBundleID)
    }
    
}
