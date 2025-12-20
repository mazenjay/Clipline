//
//  ClipboardCleaner.swift
//  Clipline
//
//  Created by mazhj on 2025/12/19.
//

import Foundation
import AppKit

class ClipboardCleaner {
    
    private let scheduler = NSBackgroundActivityScheduler(identifier: "com.cipline.cleanup")
    
    private let repo: ClipboardRepository
    
    var rulesGetter : () -> [NSPasteboard.CleanRule] = { [] }
    
    init(repo: ClipboardRepository) {
        scheduler.repeats = true
        scheduler.interval = 60 * 60 * 8
        scheduler.qualityOfService = .background
        scheduler.tolerance = 60 * 60 * 4
        self.repo = repo
    }
    
    func start() {
        scheduler.schedule { (completion: @escaping (NSBackgroundActivityScheduler.Result) -> Void) in
            Task.detached(priority: .background) {
                await self.cleanup()
                try? self.repo.vacuum()
                completion(.finished)
            }
        }
        
        Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            await self.cleanup()
        }
    }
    
    func triggerNow(rules: [NSPasteboard.CleanRule] = [], priority: TaskPriority = .userInitiated) {
        Task.detached(priority: priority) {
            await self.cleanup(rules: rules)
        }
    }
    
    private func cleanup(rules: [NSPasteboard.CleanRule] = []) {
        if !rules.isEmpty {
            self.repo.cleanup(with: rules)
            return
        }
        self.repo.cleanup(with: self.rulesGetter())
    }
}
