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
let preferencesWindowHeight: CGFloat = 800
let preferencesWindowWidth: CGFloat = 600
let defaultNSFontColor: NSColor = .labelColor
let fallbackIcon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil)!


@main
struct CliplineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {}
}

class AppContext: ObservableObject {
    static let shared = AppContext()
    
    @AppStorage("lastDatabaseCleanupDate") var lastDatabaseCleanupDate: Date = Date.now
    
    let preferences: PreferencesViewModel = PreferencesViewModel()
    var clipWindowController: ClipboardWindowController? = nil
    var prefWindowController: PreferencesWindowController? = nil
    var shortcutsService: ShortcutsService? = nil
    var clipboardService: ClipboardService? = nil

    private init() {}
    
    func openPreferencesWindow() {
        if self.prefWindowController == nil {
            let prefView = PreferencesView(viewModel: preferences)
            self.prefWindowController = PreferencesWindowController(viewModel: preferences, content: prefView)
        }
        prefWindowController?.showWindow(nil)
    }
    
}


class AppDelegate: NSObject, NSApplicationDelegate {
        
    var statusbar: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    // 2. 在 DidFinish 中进行核心初始化和 UI 显示
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
        statusbar = StatusBarController()
        
        Task {
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            AppContext.shared.clipboardService?.cleanupWithRules()
        }
    }
    
    private func setupApplication() {
        do {
            
            let clipboardService = try ClipboardService()
            
            // Set to ignore clipboard data from these apps
            clipboardService.setCheckOnCopy { sourceApp in
                !AppContext.shared.preferences.ignoredApps.contains(sourceApp)
            }
            
            // Set ignored clipboard data types
            clipboardService.setCheckOnParsed { content in
                let type = NSPasteboard.PasteboardType(content.mainCategory)
                if type.isText() {
                    return AppContext.shared.preferences.keepPlainText
                }
                if type.isFile() {
                    return AppContext.shared.preferences.keepFileLists
                }
                if type.isImage() {
                    return AppContext.shared.preferences.keepImages
                }
                
                return AppContext.shared.preferences.keepOthers
            }
            
            // Set clean rules getter
            clipboardService.setCleanRulesGetter {
                [
                    .init(
                        beforeAt: Date.before(AppContext.shared.preferences.plainTextDuration.rawValue),
                        types: [.string]
                    ),
                    .init(
                        beforeAt: Date.before(AppContext.shared.preferences.imagesDuration.rawValue),
                        types: [.tiff, .png]
                    ),
                    .init(
                        beforeAt: Date.before(AppContext.shared.preferences.fileListsDuration.rawValue),
                        types: [.fileURL]
                    )
                ]
            }
                        
            // start to listen clipboard
            try clipboardService.listen()
            let clipboardViewModel = ClipboardViewModel(clipService: clipboardService)
            let clipboardView = ClipboardView(viewModel: clipboardViewModel)
            AppContext.shared.clipboardService = clipboardService
            
            // Initialize window
            AppContext.shared.clipWindowController = ClipboardWindowController(
                viewModel: clipboardViewModel,
                content: clipboardView
            )
            AppContext.shared.shortcutsService = KeyboardShortcutsImpl()
            AppContext.shared.shortcutsService?.startListening { action in
                switch action {
                case .toggleClipboardWindow:
                    AppContext.shared.clipWindowController?.showWindow(nil)
                }
            }
            AppContext.shared.shortcutsService?.configureDefaults()
            
        } catch {
            showFatalErrorAlert(error: error)
        }
    }
    
    private func showFatalErrorAlert(error: Error) {
        // 创建 Alert
        let alert = NSAlert()
        alert.messageText = "应用程序启动失败"
        alert.informativeText = "无法初始化核心组件，应用程序将退出。\n\n错误代码: \(error.localizedDescription)"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "退出")
        
        // 运行 Alert (阻塞等待用户点击)
        alert.runModal()
        
        // ✅ 优雅退出，而不是制造崩溃
        NSApplication.shared.terminate(self)
    }
}

class StatusBarController {
    private var statusItem: NSStatusItem!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: nil)
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
        Task {
            AppContext.shared.clipboardService?.cleanup(minutes: -1)
        }
    }
    
    @objc func cleanup5m() {
        Task {
            AppContext.shared.clipboardService?.cleanup(minutes: 5)
        }
    }
    
    @objc func cleanup1h() {
        Task {
            AppContext.shared.clipboardService?.cleanup(minutes: 60)
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
        cache.countLimit = 200 // 限制缓存数量，防止无限增长
        return cache
    }()
    
    // 目标缓存尺寸。你的UI显示是 24x24，我们存 48x48 以保证 Retina 屏幕清晰，
    // 但比原图（通常 512+）节省几十倍内存。
    // Target cache size. Your UI display is 24x24, we store 48x48 to ensure clarity on Retina screens,
    // but saves several tens of times the memory compared to the original image (usually 512+).
    private nonisolated static let cacheSize = NSSize(width: 48, height: 48)
    
    /// Get Icons by Bundle ID
    /// - Parameter bundleId: For example, "com.apple.finder"
    /// - Returns: Cropped small-sized icons
    nonisolated func getAppIcon(for bundleId: String?) -> NSImage? {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return nil }
        
        let key = bundleId as NSString
        
        // 命中缓存：直接返回，耗时 O(1)，不会卡顿 UI
        // Hit cache: Directly return, takes O(1) time, will not freeze UI
        if let cachedImage = Self.iconCache.object(forKey: key) {
            return cachedImage
        }
        
        // B. 未命中缓存：尝试查找
        // 注意：urlForApplication 在首次查找时可能有微小耗时，但在 macOS 上通常很快
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let fullImage = NSWorkspace.shared.icon(forFile: url.path)
            
            // C. 关键步骤：重绘图片大小
            // 直接存 fullImage 会占用大量内存，这里将其重绘为 48x48
            let resizedImage = fullImage.resize(to: Self.cacheSize)
            
            // 存入缓存
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
        
        // 高质量重绘
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
    /// 返回智能格式化的时间字符串
//    func smartDescription() -> String {
//        let calendar = Calendar.current
//        let now = Date()
//        let formatter = DateFormatter()
//        formatter.locale = Locale.current
//
//        // ---- 情况 1：今天 ----
//        if calendar.isDateInToday(self) {
////            formatter.dateFormat = "'Today' HH:mm"
//            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
//            let timeStr = formatter.string(from: self)
//            return "\(String(localized: "Today")) \(timeStr)"
//        }
//
//        // ---- 情况 2：昨天 ----
//        if calendar.isDateInYesterday(self) {
//            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
//            let timeStr = formatter.string(from: self)
//            return "\(String(localized: "Today")) \(timeStr)"
//        }
//
//        // ---- 情况 3：7天内 → 相对时间（比如 “3 days ago”）----
//        if let days = calendar.dateComponents([.day], from: self, to: now).day,
//           days < 7 {
//            if days == 0 {
//                let hours = calendar.dateComponents([.hour], from: self, to: now).hour ?? 0
//                if hours > 0 {
//                    return "\(hours)h ago"
//                } else {
//                    let minutes = calendar.dateComponents([.minute], from: self, to: now).minute ?? 0
//                    return "\(minutes)m ago"
//                }
//            }
//            return "\(days)d ago"
//        }
//
//        // ---- 情况 4：同一年 → 月份 + 日 + 时间 ----
//        if calendar.isDate(self, equalTo: now, toGranularity: .year) {
//            formatter.dateFormat = "MMM d, HH:mm"  // Oct 10, 12:30
//            return formatter.string(from: self)
//        }
//
//        // ---- 情况 5：不同年份 ----
//        formatter.dateFormat = "yyyy MMM d, HH:mm"
//        return formatter.string(from: self)
//    }
    
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
