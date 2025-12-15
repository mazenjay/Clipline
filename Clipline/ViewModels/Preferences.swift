//
//  Preferences.swift
//  Clipline
//
//  Created by mazhj on 2025/12/7.
//

import Combine
import SwiftUI


enum HistoryDuration: Int, CaseIterable, Identifiable {
    case hours24 = 24
    case days7 = 168
    case month1 = 720
    case unlimited = 0
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .hours24: return "24 Hours"
        case .days7: return "7 Days"
        case .month1: return "1 Month"
        case .unlimited: return "Unlimited"
        }
    }
}

class PreferencesViewModel: ObservableObject {
    @AppStorage("keepPlainText") var keepPlainText = true
    @AppStorage("plainTextDuration") var plainTextDuration: HistoryDuration = .days7
    @AppStorage("keepImages") var keepImages = true
    @AppStorage("imagesDuration") var imagesDuration: HistoryDuration = .hours24
    @AppStorage("keepFileLists") var keepFileLists = true
    @AppStorage("fileListsDuration") var fileListsDuration: HistoryDuration = .hours24
    @AppStorage("keepOthers") var keepOthers = true
    @AppStorage("othersDuration") var othersDuration: HistoryDuration = .hours24
    @AppStorage("ignoredAppBundleIds") var ignoredAppBundleIds: String = "" // 逗号分隔存储
    @AppStorage("hasInitializedIgnoredApps") var hasInitializedIgnoredApps: Bool = false

    
    init() {
        if !hasInitializedIgnoredApps {
            let defaults = "com.apple.keychainaccess,com.apple.Passwords"
            if ignoredAppBundleIds.isEmpty {
                ignoredAppBundleIds = defaults
            } else {
                ignoredAppBundleIds += "," + defaults
            }
            hasInitializedIgnoredApps = true
        }
    }
    
    var ignoredApps: [String] {
        get { ignoredAppBundleIds.split(separator: ",").map(String.init) }
        set { ignoredAppBundleIds = newValue.joined(separator: ",") }
    }
    
    func addIgnoredApp(_ bundleId: String) {
        var current = ignoredApps
        if !current.contains(bundleId) {
            current.append(bundleId)
            ignoredApps = current
        }
    }
    
    func removeIgnoredApp(_ bundleId: String) {
        var current = ignoredApps
        current.removeAll { $0 == bundleId }
        ignoredApps = current
    }
    
}


class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    let viewModel: PreferencesViewModel
    let content: PreferencesView
    
    init(viewModel: PreferencesViewModel, content: PreferencesView) {
        self.viewModel = viewModel
        self.content = content
        
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = "Preferences"
        window.contentViewController = NSHostingController(rootView: AnyView(content))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace] // ✅ 切换桌面时跟随 app
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func showWindow(_ sender: Any?) {
        guard let screen = NSWorkspace.shared.screenForMouse() else {
            return
        }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - preferencesWindowWidth * 0.5
        let y = screenFrame.midY - preferencesWindowHeight * 0.5
        let rect = NSRect(
            x: x,
            y: y,
            width: preferencesWindowWidth,
            height: preferencesWindowHeight
        )

        self.window?.setFrame(rect, display: true, animate: true)
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
    }
    
    func windowWillClose(_ notification: Notification) {
        self.window?.delegate = nil
        self.window = nil
        AppContext.shared.prefWindowController = nil
        print("preferences window close")
    }
}
