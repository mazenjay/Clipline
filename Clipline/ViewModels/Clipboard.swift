//
//  Clipboard.swift
//  Clipline
//
//  Created by mazhj on 2025/12/2.
//

import Combine
import AppKit
import SwiftUI



// MARK: ClipboardViewModel
class ClipboardViewModel: ObservableObject {
    
    private let clipService: ClipboardService
    
    // MARK: History List
    @Published var histories: [ClipboardHistory] = []
    @Published var query: String = ""
    @Published var hoveredItem: ClipboardHistory?
    @Published var selections: [Int64] = []
    var shouldRespondToHover = false
    var visibleRowCount: Int = 15
    
    var hoveredIdx: Int? {
        get {
            guard let item = hoveredItem, let id = item.id else { return nil }
            return itemsForTableView.firstIndex { $0.id == id }
        }
        set {
            if let index = newValue, itemsForTableView.indices.contains(index) {
                hoveredItem = itemsForTableView[index]
            } else {
                hoveredItem = nil
            }
        }
    }
    
    var itemsForTableView: [ClipboardHistory] {
        var items = histories
        if !items.isEmpty && hasMore && !loading {
            items.append(
                ClipboardHistory(
                    id: -1,
                    sourceApp: "",
                    showContent: "Load More...",
                    hash: "",
                    dataType: "loadmore",
                    loadMore: true
                )
            )
        }
        return items
    }
    @Published var loading = false
    private var hasMore = true
    private var page = 0
    private var searchTask: Task<Void, Never>?
    
    
    // MARK: Scroll control
    @Published var scrollToRow: Int?
    @Published var scrollByStep: Int?
    @Published var currentScrollTopIndex: Int = 0
    
    
    // MARK: Preview
    var contents: [ClipboardHistoryContent] {
        guard let hoveredItem = hoveredItem,
              !NSPasteboard.PasteboardType(rawValue: hoveredItem.dataType).isText()
        else {
            return []
        }

        return clipService.fetchContent(historyId: hoveredItem.id ?? -1)
    }
    var text: NSAttributedString? {
        guard let hoveredItem = hoveredItem else {
            return nil
        }
        if NSPasteboard.PasteboardType(rawValue: hoveredItem.dataType).isMixture() {
            
            return .init(
                string: NSPasteboard.preview(
                    for: contents.map {
                        NSPasteboard.PasteboardContent(
                            type: .init($0.type),
                            content: $0.content
                        )
                    }
                ) ?? "",
                attributes: clipHistoryListAttr
            )
        } else {
             return .init(
                string: hoveredItem.showContent,
                attributes: clipHistoryListAttr
            )
        }
    }
    
    
    init(clipService: ClipboardService) {
        self.clipService = clipService
    }
}

// MARK: View Model Operations
extension ClipboardViewModel {
    func loadHistories() {
        if page > 0 && (loading || !hasMore) { return }
        
        loading = true
        let currentQuery = query
        let currentPage = page
        
        Task(priority: .userInitiated) {
            guard let result = clipService.search(
                keyword: currentQuery.isEmpty ? nil : currentQuery,
                page: currentPage
            ) else {
                await MainActor.run { self.loading = false }
                return
            }

            await MainActor.run {
                guard self.query == currentQuery else { return }
                self.hasMore = result.hasMore
                if currentPage == 0 {
                    self.histories = result.items
                    self.hoveredIdx = 0
                } else {
                    let cnt = histories.count
                    self.histories.append(contentsOf: result.items)
                    self.scrollToRow = cnt
                    self.hoveredIdx = cnt
                }
                
                self.page += 1
                self.shouldRespondToHover = false
                self.loading = false
            }
        }

    }
    
    func loadHistoriesSync() {
        guard let result = clipService.search(
            keyword: nil,
            page: 0
        ) else {
            return
        }
        self.page += 1
        self.hasMore = result.hasMore
        self.histories = result.items
        self.hoveredIdx = result.items.isEmpty ? nil : 0
        self.shouldRespondToHover = false
    }
    
    func input() {
        searchTask?.cancel()
        let snapshot = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled || query != snapshot { return }

            self.page = 0
            self.hasMore = true

            self.loadHistories()
        }
    }
    
    func paste() {
        guard AppContext.shared.accessibilityService.checkAccessibility(isPrompt: false) else {
            DispatchQueue.main.async {
                AppContext.shared.accessibilityService.showAccessibilityAuthenticationAlert()
            }
            return
        }
        Task.detached(priority: .userInitiated) {
            let content = await self.clipService.fetchContent(historyIds: self.selections)

            DispatchQueue.main.async {
                self.selections = []
                NSPasteboard.general.writeToPasteboard(items: content)
                let source = CGEventSource(stateID: .hidSystemState)
                // disable local keyboard events
                source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents], state: .eventSuppressionStateSuppressionInterval)
                
                let v = CGKeyCode(Key.v.rawValue)
                
                let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
                keyVDown?.flags = .maskCommand
                
                let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
                keyVUp?.flags = .maskCommand

                keyVDown?.post(tap: .cgAnnotatedSessionEventTap)
                keyVUp?.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
    
    func reset() {
        histories.removeAll(keepingCapacity: false)
        page = 0
        hasMore = true
        loading = false
        hoveredIdx = nil
        query = ""
        searchTask?.cancel()
        searchTask = nil
        currentScrollTopIndex = 0
        shouldRespondToHover = false
    }
}


// MARK: Clipboard Window Controller
class ClipboardWindowController: NSWindowController, NSWindowDelegate {
    let viewModel: ClipboardViewModel
    let content: ClipboardView

    init(viewModel: ClipboardViewModel, content: ClipboardView) {
        self.viewModel = viewModel
        self.content = content

        let hostingController = NSHostingController(rootView: AnyView(content))
        
        let panel = ClipboardNSWindow(viewModel: viewModel)

        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .fullScreenAuxiliary,
        ]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.styleMask.remove(.titled)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 24
        panel.contentView?.layer?.masksToBounds = true
        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension ClipboardWindowController {

    override func showWindow(_ sender: Any?) {
        guard let screen = NSWorkspace.shared.screenForMouse() else {
            return
        }
        viewModel.loadHistoriesSync()
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - clipboardWindowWidth * 0.5
        let y =
            screenFrame.midY - clipboardWindowHeight * 0.5
            + screenFrame.height * 0.175
        let rect = NSRect(
            x: x,
            y: y,
            width: clipboardWindowWidth,
            height: clipboardWindowHeight
        )
        self.window?.alphaValue = 0
        self.window?.setFrame(rect, display: true, animate: true)
        super.showWindow(sender)
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.05
                self.window?.animator().alphaValue = 1.0
            }
        }
    }

    func hideWindow(_ sender: Any?) {
        window?.orderOut(sender)
        viewModel.reset()
        AppContext.shared.clipboardService.releaseUnusedMemory()
    }

    func toggle() {
        guard let window = self.window else {
            return
        }

        if window.isVisible {
            hideWindow(nil)
        } else {
            showWindow(nil)
        }
    }

}

extension ClipboardWindowController {

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSPanel) == self.window {
            hideWindow(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        self.window?.delegate = nil
        self.window = nil
    }
}

// MARK: Clipboard Window
class ClipboardNSWindow: NSPanel {
    
    private let viewModel: ClipboardViewModel

    init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool {
        return true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            handleKeyDown(event)
        } else {
            super.sendEvent(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard self.isVisible else {
            super.sendEvent(event)
            return
        }

        if event.modifierFlags.contains(.control) {
            if event.charactersIgnoringModifiers?.lowercased() == "p" {
                navigate(direction: .up, isRepeat: event.isARepeat)
                return
            }
            if event.charactersIgnoringModifiers?.lowercased() == "n" {
                navigate(direction: .down, isRepeat: event.isARepeat)
                return
            }
        }

        switch Int(event.keyCode) {
        // Escape
        case Key.escape.rawValue:
            AppContext.shared.clipWindowController?.hideWindow(nil)
            return

        // Enter/Return
        case Key.return.rawValue:
            
            if let inputClient = self.firstResponder as? NSTextInputClient {
                if inputClient.hasMarkedText() {
                    super.sendEvent(event)
                    return
                }
            }
            
            if let hoveredItem = viewModel.hoveredItem,
               let itemId = hoveredItem.id {
                
                if hoveredItem.loadMore {
                    viewModel.loadHistories()
                    return
                }
                viewModel.selections = [itemId]
                viewModel.paste()
                AppContext.shared.clipWindowController?.hideWindow(nil)
            }
            return

        // PageUp/PageDown
        case Key.upArrow.rawValue:
            navigate(direction: .up, isRepeat: event.isARepeat)
            return

        case Key.downArrow.rawValue:
            navigate(direction: .down, isRepeat: event.isARepeat)
            return

        default:
            super.sendEvent(event)
            return
        }

    }

    private func handleKeyUp(_ event: NSEvent) {
        super.sendEvent(event)
    }

}


extension ClipboardNSWindow {
    
    enum NavigationDirection {
        case up
        case down
    }
    
    func navigate(direction: NavigationDirection, isRepeat: Bool = false) {
        let count = viewModel.itemsForTableView.count
        guard count > 0 else { return }

        // Confirm the current index. If there is no hovering item currently, we will set a default starting point.
        guard let currentIndex = viewModel.hoveredIdx else {
            return
        }

        let firstVisibleIndex = viewModel.currentScrollTopIndex
        let lastVisibleIndex = min(
            firstVisibleIndex + viewModel.visibleRowCount - 1,
            count - 1
        )

        // ✅ Determine if it is on the edge of the window
        let isAtTopEdge = (currentIndex == firstVisibleIndex)
        let isAtBottomEdge = (currentIndex == lastVisibleIndex)

//        print(
//            "currenTopIdx: \(viewModel.currentScrollTopIndex) currentIdx \(currentIndex)  count: \(count)  isAtbottom: \(isAtBottomEdge) firstidx:\(firstVisibleIndex) lastIdx:\(lastVisibleIndex)"
//        )

        var nextIndex = currentIndex
        switch direction {
        case .up:
            if isAtTopEdge && currentIndex > 0 {
                // Scrolling window, the highlighted index also decreases by one.
                nextIndex -= 1
                viewModel.shouldRespondToHover = false
                viewModel.scrollByStep = 1  // scroll up one step
            } else {
                // Otherwise, only move the highlighted index
                nextIndex -= 1
            }
        case .down:
            // If it is at the bottom of the highlighted area and not the last item in the entire list
            if isAtBottomEdge && currentIndex < count - 1 {
                nextIndex += 1
                viewModel.shouldRespondToHover = false
                viewModel.scrollByStep = -1  // scroll down one step
            } else {
                nextIndex += 1
            }
        }

        // --- Circular ---
        var didCycle = false
        if nextIndex < 0 {
            if isRepeat {
                nextIndex = 0
                if currentIndex == 0 { return }
            } else {
                nextIndex = count - 1
                viewModel.currentScrollTopIndex = count - viewModel.visibleRowCount
                didCycle = true
            }
        }
        if nextIndex >= count {
            if isRepeat {
                nextIndex = count - 1
                if currentIndex == count - 1 { return }
            } else {
                nextIndex = 0
                viewModel.currentScrollTopIndex = 0
                didCycle = true
            }
        }

        if didCycle {
            viewModel.shouldRespondToHover = false
            viewModel.scrollToRow = nextIndex
        }

        // Update Highlight
        viewModel.hoveredIdx = nextIndex

    }
    
}
