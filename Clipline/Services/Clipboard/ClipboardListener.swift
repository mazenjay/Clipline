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
    private let reop: ClipboardRepository

    init(repo: ClipboardRepository) throws {
        self.reop = repo
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func listen() throws {
        if timer != nil {
            try shutdown()
        }

        let queue = DispatchQueue(
            label: "com.mazen.clipline.clipboard-listener.queue"
        )
        timer = DispatchSource.makeTimerSource(queue: queue)
        guard let timer = timer else {
            throw Err.listenError
        }
        timer.schedule(deadline: .now(), repeating: checkInterval)

        timer.setEventHandler { [weak self] in
            self?.checkClipboard()
        }
        timer.resume()
    }
    
    func shutdown() throws {
        guard let timer = self.timer else {
            throw Err.shutdownError
        }
        timer.cancel()
        self.timer = nil
    }
    
    @objc private func checkClipboard() {
        let pastedboard = NSPasteboard.general
        let currentChangeCount = pastedboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            return  // 没有变更，直接返回
        }
        lastChangeCount = currentChangeCount
        var sourceApp: String = "unknow"
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            sourceApp = frontApp.bundleIdentifier ?? "unknow"
        }
//        let sourceApp: String = AppUtils.currentActiveAppBundleID() ?? "unknow"

        guard let clipboardContent = pastedboard.readFromPasteboard() else {
            return
        }

        let dbItems: [ClipboardHistoryItem] = clipboardContent.contents
            .enumerated().compactMap { (idx, item) -> ClipboardHistoryItem in
                ClipboardHistoryItem(
                    itemIndex: Int64(idx),
                    contents: item.enumerated().compactMap {
                        (itemIdx, data) -> ClipboardHistoryContent in
                        ClipboardHistoryContent(
                            type: data.type.rawValue,
                            content: data.content,
                            priority: Int64(itemIdx)
                        )
                    }
                )
            }
        
        let now = Date()
        let dbHitory = ClipboardHistory(
            sourceApp: sourceApp,
            showContent: clipboardContent.showContent,
            hash: clipboardContent.hash ?? clipboardContent.showContent,
            dataType: clipboardContent.mainCategory,
            lastUsedAt: now,
            createdAt: now,
            items: dbItems,
        )
        
        _ = try? reop.insert(history: dbHitory)
        
    }
}
