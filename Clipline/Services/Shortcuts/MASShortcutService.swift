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
        // 遍历所有定义的动作，如果用户没设置过，且该动作有默认值，则写入默认值
        for action in Action.allCases {
            let name = KeyboardShortcuts.Name.name(for: action)
            
            // 如果该动作还没有被存储过快捷键
            if KeyboardShortcuts.getShortcut(for: name) == nil {
                // 如果我们在 Enum 里定义了默认值
                if let defaultVal = action.defaultShortcut {
                    // 将 SwiftUI 的类型转换为 KeyboardShortcuts 的类型
                    // 注意：这里要做一点类型映射，或者直接在 Enum 里存 KeyboardShortcuts.Shortcut
                    // 为了演示简单，这里假设你构建了 Shortcut
                    
                    // 这里演示手动转换最常见的 Cmd+Shift+V
                    // 实际项目中，建议让 AppGlobalAction 直接返回 KeyboardShortcuts.Shortcut 类型（如果允许耦合的话）
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
        
        // 遍历所有动作，注册监听
        for action in Action.allCases {
            let name = KeyboardShortcuts.Name.name(for: action)
            
            // 核心绑定：当按键抬起时
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                // 回调给上层业务
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
