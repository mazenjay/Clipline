//
//  ClipboardService.swift
//  Clipline
//
//  Created by mazhj on 2025/11/30.
//

import AppKit


class ClipboardService {
    
    private let listener: ClipboardListener
    
    private let repo: ClipboardRepository
    
    var cleanRulesGetter: () -> [NSPasteboard.CleanRule] = { [] }
    
    init() throws {
        self.repo = try ClipboardRepository()
        self.listener = ClipboardListener(repo: repo)
    }
    
    func setCheckOnCopy(onCopy: @escaping (String) -> Bool) {
        listener.onCopy = onCopy
    }
    
    func setCheckOnParsed(onParsed: @escaping (NSPasteboard.ParsedResult) -> Bool) {
        listener.onParsed = onParsed
    }
    
    func setCleanRulesGetter(getter: @escaping () -> [NSPasteboard.CleanRule]) {
        cleanRulesGetter = getter
    }
    
    func startListening() { listener.listen() }
    
    func shutdown() { listener.shutdown() }
    
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
    
    func cleanupWithRules(rules: [NSPasteboard.CleanRule] = []) {
        if rules.isEmpty {
            repo.cleanup(with: rules)
            return
        }
        repo.cleanup(with: cleanRulesGetter())
    }
    
    func cleanup(minutes: Int) {
        if minutes < 0 {
            _ = try? repo.truncate()
            return
        }
        _ = try? repo.deleteRecords(olderThanMinutes: minutes)
        try? repo.vacuum()
    }
    
    func release() {
        repo.releaseUnusedMemory()
    }
}
