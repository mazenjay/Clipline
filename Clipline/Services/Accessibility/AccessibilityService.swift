//
//  Accessibility.swift
//  Clipline
//
//  Created by mazhj on 2025/12/18.
//

import Foundation
import Cocoa

class AccessibilityService {
    @discardableResult
    func checkAccessibility(isPrompt: Bool) -> Bool {
        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: isPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func showAccessibilityAuthenticationAlert() {
        // double check
        if AXIsProcessTrusted() { return }
        
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Clipline requires accessibility permissions",
            comment: "Alert title: Asking for accessibility permission"
        )
        alert.informativeText = String(
            localized: "To monitor clipboard content and simulate paste operations, the application needs accessibility permissions.\n\nPlease click 'Open Settings', then check 'Clipline' in the 'Privacy & Security' -> 'Accessibility' list.",
            comment: "Alert body: Instructions on how to enable permissions"
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(
            localized: "Open Settings",
            comment: "Button: Go to System Settings"
        ))
        alert.addButton(withTitle: String(
            localized: "Quit App",
            comment: "Button: Terminate application"
        ))
        alert.addButton(withTitle: String(
            localized: "Later",
            comment: "Button: Dismiss alert"
        ))
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            _ = openAccessibilitySettingWindow()
        case .alertSecondButtonReturn:
            NSApp.terminate(nil)
        default:
            break
        }
        
    }

    func openAccessibilitySettingWindow() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
        return NSWorkspace.shared.open(url)
    }
}
