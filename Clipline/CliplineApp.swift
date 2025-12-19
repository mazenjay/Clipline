//
//  CliplineApp.swift
//  Clipline
//
//  Created by mazhj on 2025/11/29.
//

import AppKit
import SwiftUI
import Combine

let clipboardWindowHeight: CGFloat = 432    // clipboard window height
let clipboardWindowWidth: CGFloat = 820     // clipboard window width
let clipHistoryListAttr: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor] // history record preview style of text type
let preferencesWindowHeight: CGFloat = 600
let preferencesWindowWidth: CGFloat = 900
let defaultNSFontColor: NSColor = .labelColor
let fallbackIcon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil)!


@main
struct CliplineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {}
}

class AppContext: ObservableObject {
    static let shared = AppContext()
    
    let preferences: PreferencesViewModel
    let shortcutsService: ShortcutsService
    let clipboardService: ClipboardService
    let accessibilityService: AccessibilityService
    
    var clipWindowController: ClipboardWindowController? = nil
    var prefWindowController: PreferencesWindowController? = nil
    
    @AppStorage("lastDatabaseCleanupDate") var lastDatabaseCleanupDate: Date = Date.now

    private init() {
        do {
            preferences = PreferencesViewModel()
            clipboardService = try ClipboardService()
            shortcutsService = KeyboardShortcutsImpl()
            accessibilityService = AccessibilityService()
        } catch {
            Self.showFatalErrorAlert(error: error)
        }
    }
    
    
    @MainActor func openPreferencesWindow() {
        if self.prefWindowController == nil {
            let prefView = PreferencesView(viewModel: preferences)
            self.prefWindowController = PreferencesWindowController(viewModel: preferences, content: prefView)
        }
        prefWindowController?.showWindow(nil)
    }
    
    
    @MainActor static func showFatalErrorAlert(error: Error) -> Never {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Application startup failed",
            comment: "Alert title: Fatal error"
        )
        alert.informativeText = String(
            localized: "Unable to initialize core components, the application will exit.\n\nError code: \(error.localizedDescription)",
            comment: "Alert body: Fatal error description with error code"
        )
        
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(
            localized: "Exit",
            comment: "Button: Exit application"
        ))
        
        alert.runModal()
        exit(1)
    }
    
}


class AppDelegate: NSObject, NSApplicationDelegate {
        
    var statusbar: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // check accessibility
        if !AppContext.shared.accessibilityService.checkAccessibility(isPrompt: false) {
            AppContext.shared.accessibilityService.showAccessibilityAuthenticationAlert()
        }
        
        // setup clipboard listener
        //
        // set to ignore clipboard data from these apps
        AppContext.shared.clipboardService.setCheckOnCopy { sourceApp in
            !AppContext.shared.preferences.ignoredApps.contains(sourceApp)
        }
        
        // set ignored clipboard data types
        AppContext.shared.clipboardService.setCheckOnParsed { content in
            let type = NSPasteboard.PasteboardType(content.mainCategory)
            if type.isText() { return AppContext.shared.preferences.keepPlainText }
            if type.isFile() { return AppContext.shared.preferences.keepFileLists }
            if type.isImage() { return AppContext.shared.preferences.keepImages }
            return AppContext.shared.preferences.keepOthers
        }
        
        // setup default shortcuts
        AppContext.shared.shortcutsService.configureDefaults()
        
        // setup views
        let clipViewModel = ClipboardViewModel(clipService: AppContext.shared.clipboardService)
        let clipView = ClipboardView(viewModel: clipViewModel)
        AppContext.shared.clipWindowController = ClipboardWindowController(viewModel: clipViewModel, content: clipView)
        statusbar = StatusBarController()
        
        // listen
        AppContext.shared.clipboardService.startListening()
        AppContext.shared.shortcutsService.startListening { action in
            switch action {
            case .toggleClipboardWindow:
                AppContext.shared.clipWindowController?.showWindow(nil)
            }
        }
        
        // cleanup
        DispatchQueue.global(qos: .background).async {
            AppContext.shared.clipboardService.cleanupWithRules()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppContext.shared.openPreferencesWindow()
        return true
    }
    
}

class StatusBarController {
    private var statusItem: NSStatusItem!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusIcon")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Clipline", action: #selector(toggleClipline), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences", action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear Histories", action: #selector(cleanup), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Clear Histories - Last 5 minutes ", action: #selector(cleanup5m), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Clear Histories - Last 1 hour", action: #selector(cleanup1h), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "").target = self
        

        statusItem.menu = menu
    }

    @objc func toggleClipline() {
        AppContext.shared.clipWindowController?.toggle()
    }

    @objc func openPreferences() {
        AppContext.shared.openPreferencesWindow()
    }
    
    @objc func cleanup() {
        DispatchQueue.global(qos: .utility).async {
            AppContext.shared.clipboardService.cleanup(minutes: -1)
        }
    }
    
    @objc func cleanup5m() {
        DispatchQueue.global(qos: .utility).async {
            AppContext.shared.clipboardService.cleanup(minutes: 5)
        }
    }
    
    @objc func cleanup1h() {
        DispatchQueue.global(qos: .utility).async {
            AppContext.shared.clipboardService.cleanup(minutes: 60)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}


extension NSWorkspace {
    
    // Use NSCache to automatically manage memory, which will automatically clean up when the system memory is tight
    private nonisolated static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200
        return cache
    }()
    
    
    // Target cache size. Your UI display is 24x24, we store 48x48 to ensure clarity on Retina screens,
    // but saves several tens of times the memory compared to the original image (usually 512+).
    private nonisolated static let cacheSize = NSSize(width: 48, height: 48)
    
    /// Get Icons by Bundle ID
    /// - Parameter bundleId: For example, "com.apple.finder"
    /// - Returns: Cropped small-sized icons
    nonisolated func getAppIcon(for bundleId: String?) -> NSImage? {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return nil }
        
        let key = bundleId as NSString
        
        // Hit cache: Directly return, takes O(1) time, will not freeze UI
        if let cachedImage = Self.iconCache.object(forKey: key) {
            return cachedImage
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let fullImage = NSWorkspace.shared.icon(forFile: url.path)
            
            // Redraw image size
            let resizedImage = fullImage.resize(to: Self.cacheSize)
            // put in cache
            Self.iconCache.setObject(resizedImage, forKey: key)
            
            return resizedImage
        } else {
            return nil
        }
    }
    
    func checkAppIconCache(for bundleId: String?) -> NSImage? {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return nil }
        return Self.iconCache.object(forKey: bundleId as NSString)
    }
    
    
    func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main
    }
    
}


extension NSImage {
    nonisolated func resize(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        self.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        
        newImage.unlockFocus()
        return newImage
    }
}


extension Date {
    func smartDescription() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 创建 Formatter
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current // 确保跟随系统语言
        
        // ---- 情况 1 & 2：今天 / 昨天 ----
        if calendar.isDateInToday(self) {
            // 获取 "14:30"
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
            let timeStr = dateFormatter.string(from: self)
            
            // 拼接: "今天 14:30"
            // String(localized: "Today") 会自动进入 .xcstrings 等待翻译
            return "\(String(localized: "Today")) \(timeStr)"
        }
        
        if calendar.isDateInYesterday(self) {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
            let timeStr = dateFormatter.string(from: self)
            return "\(String(localized: "Yesterday")) \(timeStr)"
        }

        // ---- 情况 3：7天内 → 相对时间 (使用苹果原生相对时间格式化器) ----
        if let days = calendar.dateComponents([.day], from: self, to: now).day, days < 7 {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .short // .short 会输出 "3h ago", "3d ago" 或 "3小时前", "3天前"
            relativeFormatter.locale = Locale.current
            return relativeFormatter.localizedString(for: self, relativeTo: now)
        }

        // ---- 情况 4：同一年 → 月日 + 时间 ----
        if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            // 使用 Template，系统会自动根据语言调整顺序
            // 英文: "Oct 10, 14:30"
            // 中文: "10月10日 14:30"
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMdHHmm")
            return dateFormatter.string(from: self)
        }

        // ---- 情况 5：不同年份 ----
        // 英文: "Oct 10, 2023, 14:30"
        // 中文: "2023年10月10日 14:30"
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMdHHmm")
        return dateFormatter.string(from: self)
    }
    
    
    static func before(_ hours: Int) -> Self? {
        guard hours != 0 else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .hour, value: -hours, to: now)
    }
}
