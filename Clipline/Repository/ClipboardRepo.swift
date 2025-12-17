//
//  Clipboard.swift
//  Clipline
//
//  Created by mazhj on 2025/11/29.
//

import Foundation
import GRDB


public final class ClipboardRepository: @unchecked Sendable {

    private let dbQueue: DatabaseQueue

    public nonisolated init(inMemory: Bool = false) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA foreign_keys=ON")
        }

        if inMemory {
            // In-memory database, for testing
            self.dbQueue = try DatabaseQueue(configuration: config)
        } else {
            let fm = FileManager.default
            let dir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Clipline", isDirectory: true)

            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let dbPath = dir.appendingPathComponent("clipboard.db").path
            print("Database path: \(dbPath)")
            self.dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
        }

        // Establish table structure immediately upon initialization
        try createSchema()
    }
    
    private nonisolated func createSchema() throws {
        try dbQueue.write { db in
            try db.create(table: "clipboard_history", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source_app", .text).notNull()
                t.column("show_content", .text).notNull()
                t.column("hash", .text).notNull().unique()
                t.column("data_type", .text).notNull()
                t.column("is_favorited", .boolean).notNull().defaults(to: false)
                t.column("is_pinned", .boolean).notNull().defaults(to: false)
                t.column("tags", .text)
                t.column("last_used_at", .integer)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "clipboard_history_item", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("history_id", .integer).notNull()
                    .indexed()
                    .references("clipboard_history", onDelete: .cascade)
                t.column("item_index", .integer).notNull()
            }

            try db.create(table: "clipboard_history_content", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("item_id", .integer).notNull()
                    .indexed()
                    .references("clipboard_history_item", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("content", .blob).notNull()
                t.column("priority", .integer).notNull()
                t.uniqueKey(["item_id", "type"])
            }

            // Indexes
            try db.create(index: "idx_history_created_at", on: "clipboard_history", columns: ["created_at"], ifNotExists: true)
            try db.create(index: "idx_history_last_used_at", on: "clipboard_history", columns: ["last_used_at"], ifNotExists: true)
            try db.create(index: "idx_history_data_type", on: "clipboard_history", columns: ["data_type"], ifNotExists: true)
            try db.create(index: "idx_history_source_app", on: "clipboard_history", columns: ["source_app"], ifNotExists: true)
            try db.create(index: "idx_content_priority", on: "clipboard_history_content", columns: ["item_id", "priority"], ifNotExists: true)
        }
    }

    private nonisolated func applicationSupportDirectory() -> URL? {
        do {
            let fm = FileManager.default
            let dir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDir = dir.appendingPathComponent(
                "Clipline",
                isDirectory: true
            )

            if !fm.fileExists(atPath: appDir.path) {
                try fm.createDirectory(
                    at: appDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            return appDir
        } catch {
            print("Failed to get app support directory: \(error)")
            return nil
        }
    }

}


extension ClipboardRepository {
    
    struct SearchFilter: @unchecked Sendable {
        var keyword: String?
        var dataType: String?
        var isFavorited: Bool?
        var isPinned: Bool?
        var tags: [String]?
        var dateFrom: Date?
        var dateTo: Date?
        var sourceApp: String?
    }
    
    // MARK: - Upsert
    
    @discardableResult
    nonisolated func upsert(history: inout ClipboardHistory) throws -> Int64 {
        guard !history.items.isEmpty else { throw DatabaseError.invalidData }
        
        return try dbQueue.write { db in
            if let existing = try ClipboardHistory.filter(Column("hash") == history.hash).fetchOne(db) {
                try db.execute(
                    sql: "UPDATE clipboard_history SET last_used_at = ?, created_at = ? WHERE id = ?",
                    arguments: [history.lastUsedAt, history.createdAt, existing.id]
                )
                return existing.id!
            }
            
            return try history.performInsert(db)
        }
    }
    
    // MARK: - Insert
    
    @discardableResult
    nonisolated func insert(history: inout ClipboardHistory) throws -> Int64 {
        return try dbQueue.write { db in
            try history.performInsert(db)
        }
    }
    
    
    // MARK: - Search with Pagination
    
    nonisolated func search(
        filter: SearchFilter,
        page: Int = 0,
        pageSize: Int = 30
    ) throws -> PagedResult<ClipboardHistory> {
        
        return try dbQueue.read { db in
            var request = ClipboardHistory.all()
            
            // Apply filters
            if let keyword = filter.keyword, !keyword.isEmpty {
                request = request.filter(
                    Column("show_content").like("%\(keyword)%")
                )
            }
            
            if let dataType = filter.dataType {
                request = request.filter(Column("data_type") == dataType)
            }
            
            if let isFavorited = filter.isFavorited {
                request = request.filter(Column("is_favorited") == isFavorited)
            }
            
            if let isPinned = filter.isPinned {
                request = request.filter(Column("is_pinned") == isPinned)
            }
            
            if let sourceApp = filter.sourceApp {
                request = request.filter(Column("source_app") == sourceApp)
            }
            
            if let dateFrom = filter.dateFrom {
                request = request.filter(Column("created_at") >= dateFrom)
            }
            
            if let dateTo = filter.dateTo {
                request = request.filter(Column("created_at") <= dateTo)
            }
            
            // Order by lastUsedAt (nulls last), then createdAt
            request = request.order(
                Column("last_used_at").desc,
                Column("created_at").desc
            )
            
            // Fetch one extra to check if there are more pages
            let offset = page * pageSize
            let items = try request
                .limit(pageSize + 1, offset: offset)
                .fetchAll(db)
            
            let hasMore = items.count > pageSize
            let resultItems = hasMore ? Array(items.dropLast()) : items
            
            return PagedResult(
                items: resultItems,
                totalCount: 0, // Can be computed separately if needed
                hasMore: hasMore,
                currentPage: page,
                pageSize: pageSize
            )
        }
    }

    // MARK: - Update Last Used
    
    nonisolated func updateLastUsed(historyIds: [Int64]) throws {
        
        guard !historyIds.isEmpty else {
            throw DatabaseError.invalidData
        }
        
        try dbQueue.write { db in
            let now = Date()
            try db.execute(
                sql: """
                    UPDATE clipboard_history 
                    SET last_used_at = ? 
                    WHERE id IN (\(historyIds.map { String($0) }.joined(separator: ",")))
                    """,
                arguments: [now]
            )
        }
    }
    
    // MARK: - Select with Full Data
    
    nonisolated func selectData(historyIds: [Int64]) throws -> [ClipboardHistory] {
        
        guard !historyIds.isEmpty else {
            return []
        }
        
        return try dbQueue.read { db in
            // Fetch histories
            let histories = try ClipboardHistory
                .filter(historyIds.contains(Column("id")))
                .fetchAll(db)
            
            var result: [ClipboardHistory] = []
            
            for var history in histories {
                // Fetch items for this history
                let items = try ClipboardHistoryItem
                    .filter(Column("history_id") == history.id!)
                    .order(Column("item_index"))
                    .fetchAll(db)
                
                var itemsWithContent: [ClipboardHistoryItem] = []
                
                for var item in items {
                    // Fetch contents for this item
                    let contents = try ClipboardHistoryContent
                        .filter(Column("item_id") == item.id!)
                        .order(Column("priority"))
                        .fetchAll(db)
                    
                    item.contents = contents
                    itemsWithContent.append(item)
                }
                
                history.items = itemsWithContent
                result.append(history)
            }
            
            // Maintain the order of input IDs
            let orderedResult = historyIds.compactMap { id in
                result.first { $0.id == id }
            }
            
            return orderedResult
        }
    }
    
    // MARK: - Check if Hash Exists
    
    nonisolated func exists(hash: String) throws -> Bool {
        return try dbQueue.read { db in
            try ClipboardHistory
                .filter(Column("hash") == hash)
                .fetchCount(db) > 0
        }
    }
    
    nonisolated func releaseUnusedMemory() {
        try? dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA shrink_memory")
        }
    }
    
    
    // MARK: - Delete by Time Range
    
    nonisolated func vacuum() throws {
        try dbQueue.vacuum()
    }
    
    @discardableResult
    nonisolated func truncate() throws -> Int {
        return try dbQueue.write { db in
            let deleted = try ClipboardHistory.deleteAll(db)
            try? db.execute(sql: "DELETE FROM sqlite_sequence WHERE name = 'clipboard_history'")
            try? db.execute(sql: "DELETE FROM sqlite_sequence WHERE name = 'clipboard_history_item'")
            try? db.execute(sql: "DELETE FROM sqlite_sequence WHERE name = 'clipboard_history_content'")
            return deleted
        }
    }
    
    @discardableResult
    nonisolated func deleteOldRecords(olderThan duration: TimeInterval) throws -> Int {
        return try dbQueue.write { db in
            let cutoffDate = Date().addingTimeInterval(-duration)
            
            // Foreign key cascades will handle related items and contents
            let deleted = try ClipboardHistory
                .filter(Column("created_at") > cutoffDate)
                .filter(Column("is_favorited") == false) // Don't delete favorited
                .filter(Column("is_pinned") == false)    // Don't delete pinned
                .deleteAll(db)
            
            return deleted
        }
    }
    
    @discardableResult
    nonisolated func deleteOldRecords(types: [String], olderThan beforeAt: Date) throws -> Int {
        
        return try dbQueue.write { db in
            let deleted = try ClipboardHistory
                .filter(Column("created_at") < beforeAt)
                .filter(Column("is_favorited") == false)
                .filter(types.contains(Column("data_type")))
                .deleteAll(db)
            return deleted
        }
    }
    
    // MARK: - Convenience Delete Methods
    
    /// Delete records older than specified minutes
    nonisolated func deleteRecords(olderThanMinutes minutes: Int) throws -> Int {
        return try deleteOldRecords(olderThan: TimeInterval(minutes * 60))
    }
    
    /// Delete records older than specified hours
    nonisolated func deleteRecords(olderThanHours hours: Int) throws -> Int {
        return try deleteOldRecords(olderThan: TimeInterval(hours * 3600))
    }
    
    /// Delete records older than specified days
    nonisolated func deleteRecords(olderThanDays days: Int) throws -> Int {
        return try deleteOldRecords(olderThan: TimeInterval(days * 86400))
    }
    
    // MARK: - Update Operations
    
    nonisolated func toggleFavorite(historyId: Int64) throws {
        try dbQueue.write { db in
            guard var history = try ClipboardHistory.fetchOne(db, key: historyId) else {
                throw DatabaseError.recordNotFound
            }
            history.isFavorited.toggle()
            try history.update(db)
        }
    }
    
    nonisolated func togglePin(historyId: Int64) throws {
        try dbQueue.write { db in
            guard var history = try ClipboardHistory.fetchOne(db, key: historyId) else {
                throw DatabaseError.recordNotFound
            }
            history.isPinned.toggle()
            try history.update(db)
        }
    }
    
    
    
    nonisolated func updateTags(historyId: Int64, tags: [String]) throws {
        try dbQueue.write { db in
            guard var history = try ClipboardHistory.fetchOne(db, key: historyId) else {
                throw DatabaseError.recordNotFound
            }
            history.tags = tags
            try history.update(db)
        }
    }
    
    // MARK: - Delete Single Record
    
    nonisolated func delete(historyId: Int64) throws {
        _ = try dbQueue.write { db in
            try ClipboardHistory.deleteOne(db, key: historyId)
        }
    }
    
    // MARK: - Statistics
    
    nonisolated func getTotalCount() throws -> Int {
        return try dbQueue.read { db in
            try ClipboardHistory.fetchCount(db)
        }
    }
    
    nonisolated func getCountByDataType() throws -> [String: Int] {
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT data_type, COUNT(*) as count 
                FROM clipboard_history 
                GROUP BY data_type
                """)
            
            var result: [String: Int] = [:]
            for row in rows {
                let dataType: String = row["data_type"]
                let count: Int = row["count"]
                result[dataType] = count
            }
            return result
        }
    }
    
    
    nonisolated private func performInsert(_ db: Database, history: ClipboardHistory) throws -> Int64 {
        guard !history.items.isEmpty else {
            throw DatabaseError.invalidData
        }
        
        // Insert main history record
        var mutableHistory = history
        try mutableHistory.insert(db) // 直接使用传入的 db
        
        guard let historyId = mutableHistory.id else {
            throw DatabaseError.insertFailed
        }
        
        // Insert items and contents
        for (index, item) in history.items.enumerated() {
            var mutableItem = item
            mutableItem.historyId = historyId
            mutableItem.itemIndex = Int64(index)
            try mutableItem.insert(db)
            
            guard let itemId = mutableItem.id else {
                throw DatabaseError.insertFailed
            }
            
            // Insert contents
            for content in item.contents {
                var mutableContent = content
                mutableContent.itemId = itemId
                try mutableContent.insert(db)
            }
        }
        
        return historyId
    }
}
