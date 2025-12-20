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
            return Shortcut(key: .v, modifiers: [.command, .shift], id: 1, description: "toggle clipboard histories")
        }
    }
}

protocol ShortcutsService {
    
    /// 1. Configure initial state (such as setting default shortcut keys)
    func configureDefaults()
    
    /// 2. Register Listener
    /// - Parameter actionHandler: Callbacks when an action is triggered
    func startListening(actionHandler: @escaping (Action) -> Void)
    
    /// 3. (Optional) Pause listening (for example, when the user is recording shortcut keys, or the App is in a special state)
    func pauseListening()
    
    /// 4. (Optional) Resume Listening
    func resumeListening()
    
}
