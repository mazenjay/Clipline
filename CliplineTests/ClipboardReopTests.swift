//
//  ClipboardReopTests.swift
//  Clipline
//
//  Created by mazhj on 2025/11/29.
//

import Testing
import Foundation
import GRDB
@testable import Clipline // 替换为你的 Target 名称

@Suite("Clipboard Repository Tests")
struct ClipboardRepoTests {
    
    let repo: ClipboardRepository
    let fileManager = FileManager.default
    
    init() async throws {
        // 1. 初始化 Repository
        self.repo = try ClipboardRepository(inMemory: true)
        
        //To ensure the test environment is clean, first try to delete the old database files.
//        try cleanupDatabase()
        
    }
    
    // 清理数据库文件的辅助函数
    private func cleanupDatabase() throws {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dbPath = appSupport.appendingPathComponent("Clipline/clipboard.db")
            let shmPath = appSupport.appendingPathComponent("Clipline/clipboard.db-shm")
            let walPath = appSupport.appendingPathComponent("Clipline/clipboard.db-wal")
            
            for path in [dbPath, shmPath, walPath] {
                if fileManager.fileExists(atPath: path.path) {
                    try fileManager.removeItem(at: path)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func createSampleHistory(
        content: String = "Test Content",
        hash: String = UUID().uuidString,
        app: String = "Xcode",
        isPinned: Bool = false,
        isFavorited: Bool = false,
        createdDate: Date = Date()
    ) -> ClipboardHistory {
        
        let contentData = ClipboardHistoryContent(
            itemId: 0,
            type: "public.utf8-plain-text",
            content: content.data(using: .utf8)!
        )
        
        let item = ClipboardHistoryItem(
            historyId: 0,
            itemIndex: 0,
            contents: [contentData]
        )
        
        return ClipboardHistory(
            sourceApp: app,
            showContent: content,
            hash: hash,
            dataType: "text",
            isFavorited: isFavorited,
            isPinned: isPinned,
            tags: ["test", "unit-test"],
            createdAt: createdDate,
            items: [item]
        )
    }
    
    // MARK: - Tests
    
    @Test("Basic Insert and Fetch")
    func testInsertAndFetch() async throws {
        var history = createSampleHistory(content: "Hello World")
        
        // 1. Insert
        let id = try repo.insert(history: &history)
        #expect(id > 0)
        
        // 2. Check existence by Hash
        let exists = try await repo.exists(hash: history.hash)
        #expect(exists == true)
        
        // 3. Fetch full data
        let fetchedItems = try repo.selectData(historyIds: [id])
        let fetched = try #require(fetchedItems.first)
        
        // Verify Data
        #expect(fetched.showContent == "Hello World")
        #expect(fetched.sourceApp == "Xcode")
        #expect(fetched.tags == ["test", "unit-test"])
        
        // Verify Nested Relationships
        let item = try #require(fetched.items.first)
        let content = try #require(item.contents.first)
        
        #expect(content.type == "public.utf8-plain-text")
        let contentString = await String(data: content.content, encoding: .utf8)
        #expect(contentString == "Hello World")
    }
    
    @Test("Search functionality")
    func testSearch() async throws {
        // Prepare Data
        var h1 = createSampleHistory(content: "Apple", hash: "1", app: "Finder")
        var h2 = createSampleHistory(content: "Banana", hash: "2", app: "Safari", isFavorited: true)
        var h3 = createSampleHistory(content: "Apricot", hash: "3", app: "Finder")
        
        try repo.insert(history: &h1)
        try repo.insert(history: &h2)
        try repo.insert(history: &h3)
        
        // 1. Search Keyword "Ap" (Should match Apple and Apricot)
        let filterKeyword = ClipboardRepository.SearchFilter(keyword: "Ap")
        let resultKeyword = try repo.search(filter: filterKeyword)
        #expect(resultKeyword.items.count == 2)
        
        // 2. Search Source App "Safari"
        let filterApp = ClipboardRepository.SearchFilter(sourceApp: "Safari")
        let resultApp = try repo.search(filter: filterApp)
        #expect(resultApp.items.count == 1)
        await #expect(resultApp.items.first?.showContent == "Banana")
        
        // 3. Search Favorited
        let filterFav = ClipboardRepository.SearchFilter(isFavorited: true)
        let resultFav = try repo.search(filter: filterFav)
        #expect(resultFav.items.count == 1)
        await #expect(resultFav.items.first?.hash == "2")
    }
    
    @Test("Pagination")
    func testPagination() async throws {
        // Insert 5 records
        for i in 1...5 {
            var h = createSampleHistory(content: "Item \(i)", hash: "\(i)")
            try repo.insert(history: &h)
        }
        
        // Page 1 (Size 2) -> Should get 2 items, hasMore = true
        let page1 = try await repo.search(filter: .init(), page: 0, pageSize: 2)
        #expect(page1.items.count == 2)
        #expect(page1.hasMore == true)
        
        // Page 3 (Size 2) -> Should get 1 item (Item 5), hasMore = false
        // (Page 0: 1-2, Page 1: 3-4, Page 2: 5)
        let page3 = try await repo.search(filter: .init(), page: 2, pageSize: 2)
        #expect(page3.items.count == 1)
        #expect(page3.hasMore == false)
    }
    
    @Test("Update Operations (Pin, Favorite, Tags)")
    func testUpdates() async throws {
        var history = createSampleHistory()
        let id = try repo.insert(history: &history)
        
        // Toggle Favorite
        try repo.toggleFavorite(historyId: id)
        var fetched = try repo.selectData(historyIds: [id]).first!
        #expect(fetched.isFavorited == true)
        
        // Toggle Pin
        try repo.togglePin(historyId: id)
        fetched = try repo.selectData(historyIds: [id]).first!
        #expect(fetched.isPinned == true)
        
        // Update Tags
        let newTags = ["swift", "ui"]
        try repo.updateTags(historyId: id, tags: newTags)
        fetched = try repo.selectData(historyIds: [id]).first!
        #expect(fetched.tags == newTags)
        
        // Update Last Used
        try repo.updateLastUsed(historyIds: [id])
        fetched = try repo.selectData(historyIds: [id]).first!
        // lastUsedAt should be close to now
        #expect(fetched.lastUsedAt != nil)
    }
    
    @Test("Delete Old Records")
    func testDeleteOldRecords() async throws {
        let now = Date()
        let oneDay: TimeInterval = 86400
        
        // 1. Create OLD record (2 days ago) - Should be deleted
        let oldDate = now.addingTimeInterval(-oneDay * 2)
        var oldHistory = createSampleHistory(content: "Old", hash: "old", createdDate: oldDate)
        
        // 2. Create NEW record (1 hour ago) - Should be kept
        var newHistory = createSampleHistory(content: "New", hash: "new", createdDate: now)
        
        // 3. Create OLD but PINNED record - Should be kept
        var pinnedOldHistory = createSampleHistory(content: "Pinned Old", hash: "pinned", isPinned: true, createdDate: oldDate)
        
        try repo.insert(history: &oldHistory)
        try repo.insert(history: &newHistory)
        try repo.insert(history: &pinnedOldHistory)
        
        // Action: Delete records older than 1 day
        let deletedCount = try repo.deleteRecords(olderThanDays: 1)
        
        // Assertions
        #expect(deletedCount == 1) // Only "Old" should be deleted
        
        let allItems = try await repo.search(filter: .init()).items
        #expect(allItems.count == 2)
        
        let remainingHashes = allItems.map { $0.hash }
        #expect(remainingHashes.contains("new"))
        #expect(remainingHashes.contains("pinned"))
        #expect(!remainingHashes.contains("old"))
    }
    
    @Test("Statistics")
    func testStatistics() async throws {
        var h1 = createSampleHistory(content: "A", hash: "1")
        var h2 = createSampleHistory(content: "B", hash: "2")
        try repo.insert(history: &h1)
        try repo.insert(history: &h2)
        
        let total = try repo.getTotalCount()
        #expect(total == 2)
        
        let typeCounts = try repo.getCountByDataType()
        #expect(typeCounts["text"] == 2)
    }
}
