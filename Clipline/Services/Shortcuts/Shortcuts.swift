//
//  Shortcuts.swift
//  Clipline
//
//  Created by mazhj on 2025/11/30.
//

import Foundation
import Carbon
import AppKit


struct Shortcut {
    let key: Key
    let modifiers: NSEvent.ModifierFlags
    let id: UInt32
    let description: String
    
    var display: String {
        return "\(modifiers.symbol)\(key.symbol)"
    }
}


enum Action: String, CaseIterable, Identifiable {
    case toggleClipboardWindow
    
    var id: String { rawValue }
    
    var defaultShortcut: Shortcut? {
        switch self {
        case .toggleClipboardWindow:
            return Shortcut(key: .v, modifiers: [.command, .shift], id: 1, description: "触发剪切板历史窗口")
        }
    }
}

protocol ShortcutsService {
    
    /// 1. 配置初始状态（比如注册默认快捷键）
    func configureDefaults()
    
    /// 2. 注册监听器
    /// - Parameter actionHandler: 当某个动作被触发时的回调
    func startListening(actionHandler: @escaping (Action) -> Void)
    
    /// 3. (可选) 暂停监听（比如用户正在录制快捷键时，或者 App 处于特殊状态）
    func pauseListening()
    
    /// 4. (可选) 恢复监听
    func resumeListening()
    
}
