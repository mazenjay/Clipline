//
//  Models.swift
//  Clipline
//
//  Created by mazhj on 2025/11/29.
//

import Foundation
import GRDB
import Carbon

// MARK: - Errors

enum DatabaseError: Error {
    case notConnected
    case insertFailed
    case updateFailed
    case deleteFailed
    case queryFailed
    case invalidData
    case recordNotFound
}

// MARK: - Paged Result

struct PagedResult<T> {
    let items: [T]
    let totalCount: Int
    let hasMore: Bool
    let currentPage: Int
    let pageSize: Int
}

// MARK: - ClipboardHistory Model

struct ClipboardHistory: @unchecked Sendable, Identifiable, Equatable, FetchableRecord, MutablePersistableRecord {
    
    // GRDB
    static let databaseTableName = "clipboard_history"
    static let historyItems = hasMany(ClipboardHistoryItem.self)
    
    // Database fields
    var id: Int64?
    var sourceApp: String
    var showContent: String
    var hash: String
    var dataType: String
    var isFavorited: Bool
    var isPinned: Bool
    var tags: [String]?
    var lastUsedAt: Date?
    var createdAt: Date?

    // Not in DB
    var items: [ClipboardHistoryItem] = []
    var loadMore: Bool = false
    

    init(id: Int64? = nil,
         sourceApp: String = "",
         showContent: String = "",
         hash: String = "",
         dataType: String = "",
         isFavorited: Bool = false,
         isPinned: Bool = false,
         tags: [String]? = nil,
         lastUsedAt: Date? = nil,
         createdAt: Date? = nil,
         items: [ClipboardHistoryItem] = [],
         loadMore: Bool = false) {
        self.id = id
        self.sourceApp = sourceApp
        self.showContent = showContent
        self.hash = hash
        self.dataType = dataType
        self.isFavorited = isFavorited
        self.isPinned = isPinned
        self.tags = tags
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.items = items
        self.loadMore = loadMore
    }

    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source_app"] = sourceApp
        container["show_content"] = showContent
        container["hash"] = hash
        container["data_type"] = dataType
        container["is_favorited"] = isFavorited
        container["is_pinned"] = isPinned

        if let tags = tags,
           let jsonData = try? JSONEncoder().encode(tags),
           let json = String(data: jsonData, encoding: .utf8) {
            container["tags"] = json
        } else {
            container["tags"] = nil
        }

        container["last_used_at"] = lastUsedAt
        container["created_at"] = createdAt
    }

    nonisolated init(row: Row) {
        id = row["id"]
        sourceApp = row["source_app"]
        showContent = row["show_content"]
        hash = row["hash"]
        dataType = row["data_type"]
        isFavorited = row["is_favorited"]
        isPinned = row["is_pinned"]

        if let tagsString: String = row["tags"],
           let data = tagsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            tags = decoded
        } else {
            tags = nil
        }

        lastUsedAt = row["last_used_at"]
        createdAt = row["created_at"]
        items = []
    }
    
    static func == (lhs: ClipboardHistory, rhs: ClipboardHistory) -> Bool {
        guard let lhsId = lhs.id, let rhsId = rhs.id else {
            return false
        }
        return lhsId == rhsId
    }
    
    /// Just for preservation, the ids of child elements will not be synchronized.
    mutating nonisolated func performInsert(_ db: Database) throws -> Int64 {
        guard !self.items.isEmpty else {
            throw DatabaseError.invalidData
        }
        
        // Insert main history record
        try insert(db)
        
        guard let historyId = id else { throw DatabaseError.insertFailed }
        
        // Insert items and contents
        for (index, item) in items.enumerated() {
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

// MARK: - ClipboardHistoryItem Model

struct ClipboardHistoryItem: @unchecked Sendable {
    var id: Int64?
    var historyId: Int64
    var itemIndex: Int64
    
    // Relationships
    var contents: [ClipboardHistoryContent] = []
    
    init(id: Int64? = nil,
         historyId: Int64 = -1,
         itemIndex: Int64 = 0,
         contents: [ClipboardHistoryContent] = []) {
        self.id = id
        self.historyId = historyId
        self.itemIndex = itemIndex
        self.contents = contents
    }
}

extension ClipboardHistoryItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboard_history_item"
    
    // Define relationships
    static let history = belongsTo(ClipboardHistory.self)
    static let historyContents = hasMany(ClipboardHistoryContent.self)
    
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["history_id"] = historyId
        container["item_index"] = itemIndex
    }
    
    nonisolated init(row: Row) {
        id = row["id"]
        historyId = row["history_id"]
        itemIndex = row["item_index"]
        contents = []
    }
}

// MARK: - ClipboardHistoryContent Model

struct ClipboardHistoryContent: @unchecked Sendable {
    var id: Int64?
    var itemId: Int64
    var type: String
    var content: Data
    var priority: Int64
    
    init(id: Int64? = nil,
         itemId: Int64 = -1,
         type: String,
         content: Data,
         priority: Int64 = 0) {
        self.id = id
        self.itemId = itemId
        self.type = type
        self.content = content
        self.priority = priority
    }
}

extension ClipboardHistoryContent: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboard_history_content"
    
    // Define relationships
    static let item = belongsTo(ClipboardHistoryItem.self)
    
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["item_id"] = itemId
        container["type"] = type
        container["content"] = content
        container["priority"] = priority
    }
    
    nonisolated init(row: Row) {
        id = row["id"]
        itemId = row["item_id"]
        type = row["type"]
        content = row["content"]
        priority = row["priority"]
    }
}



// MARK:  Preferences Model
