//
//  ClipboardService.swift
//  Clipline
//
//  Created by mazhj on 2025/11/30.
//

import AppKit


class ClipboardService {
    
    private let listener: ClipboardListener
    private let cleaner: ClipboardCleaner
    private let repo: ClipboardRepository
    

    
    var cleanRulesGetter: (() -> [NSPasteboard.CleanRule])? {
        get { cleaner.rulesGetter }
        set { cleaner.rulesGetter = newValue ?? {[]} }
    }
    
    init() throws {
        self.repo = try ClipboardRepository()
        self.listener = ClipboardListener(repo: repo)
        self.cleaner = ClipboardCleaner(repo: repo)
    }
    
    
    func startListening() {
        listener.listen()
        cleaner.start()
    }
    
    func shutdown() { listener.shutdown() }
    
    func cleanup(rules: [NSPasteboard.CleanRule] = []) {
        cleaner.triggerNow(rules: rules)
    }
    
    func search(keyword: String?, pageSize: Int = 30, page: Int = 0) -> (items: [ClipboardHistory], hasMore: Bool)? {
        guard
            let result = try? repo.search(
                filter: ClipboardRepository.SearchFilter(keyword: keyword),
                page: page
            )

        else {
            return nil
        }
        
        return (result.items, result.hasMore)

    }
    
    func fetchContent(historyId: Int64) -> [ClipboardHistoryContent] {
        guard let histories = try? repo.selectData(historyIds: [historyId]),
              let histroy = histories.first else {
            return []
        }
        
        var contents: [ClipboardHistoryContent] = []
        for item in histroy.items {
            guard let content = item.contents.first else {
                continue
            }
            contents.append(content)
        }
        
        return contents
    }
    
    func fetchContent(historyIds: [Int64]) -> [[NSPasteboard.PasteboardContent]] {
        guard let histories = try? repo.selectData(historyIds: historyIds) else { return [] }
        var items: [[NSPasteboard.PasteboardContent]] = []
        for history in histories {
            for item in history.items {
                var contents: [NSPasteboard.PasteboardContent] = []
                for content in item.contents {
                    contents.append(
                        NSPasteboard.PasteboardContent(
                            type: NSPasteboard.PasteboardType(
                                rawValue: content.type
                            ),
                            content: content.content
                        )
                    )
                }
                if contents.isEmpty {
                    continue
                }
                items.append(contents)
            }
        }
        return items
    }
    
    func releaseUnusedMemory() {
        repo.releaseUnusedMemory()
    }
}

extension ClipboardService {
    @discardableResult
    func checkOnCopy(_ handler: @escaping (String) -> Bool) -> Self {
        listener.onCopy = handler
        return self
    }
    
    @discardableResult
    func checkOnParsed(_ handler: @escaping (NSPasteboard.ParsedResult) -> Bool) -> Self {
        listener.onParsed = handler
        return self
    }
    
    @discardableResult
    func cleanRules (_ handler: @escaping () -> [NSPasteboard.CleanRule]) -> Self {
        cleaner.rulesGetter = handler
        return self
    }
}
