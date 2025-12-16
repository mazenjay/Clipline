//
//  MASShortcutService.swift
//  Clipline
//
//  Created by mazhj on 2025/12/2.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static func name(for action: Action) -> Self {
        Self(action.rawValue)
    }
}

extension Action {
    var name: KeyboardShortcuts.Name {
        return KeyboardShortcuts.Name(self.rawValue)
    }
}

extension Shortcut {
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        return .init(.init(rawValue: key.rawValue), modifiers: modifiers)
    }
}

final class KeyboardShortcutsImpl: ShortcutsService {
    
    private var actionHandler: ((Action) -> Void)?
    
    func configureDefaults() {
        for action in Action.allCases {
            let name = KeyboardShortcuts.Name.name(for: action)
            if KeyboardShortcuts.getShortcut(for: name) == nil {
                if let defaultVal = action.defaultShortcut {
                    if action == .toggleClipboardWindow {
                         KeyboardShortcuts.setShortcut(
                            defaultVal.keyboardShortcut,
                            for: name
                        )
                    }
                }
            }
        }
    }
    
    func startListening(actionHandler: @escaping (Action) -> Void) {
        self.actionHandler = actionHandler
        for action in Action.allCases {
            let name = KeyboardShortcuts.Name.name(for: action)
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.actionHandler?(action)
            }
        }
    }
    
    func pauseListening() {
        KeyboardShortcuts.disable(.name(for: .toggleClipboardWindow))
        // 遍历所有去 disable
    }
    
    func resumeListening() {
        KeyboardShortcuts.enable(.name(for: .toggleClipboardWindow))
        // 遍历所有去 enable
    }
}
